use Bitwise

defmodule Coap do
	@vsn "d18-01"
	@moduledoc """
	This module provides functionality for creating, inspecting, encoding,
	and decoding CoAP messages. It does not currently provide any server-like
	functionality.

	It it based on draft 18 of the coap protocol.
	"""

	defmodule Message do
		@moduledoc """
		This module represents a single coap message as well as providing
		encoding and decoding functionality.
		"""

		defstruct version: 1,
		          type: 0,
		          token: <<>>,
		          code: 0,
		          id: 0,
		          options: [],
		          payload: <<>>

		@doc "Converts the message struct to a binary coap message."
		def to_binary(msg) when is_map msg do
			1 = msg.version
			<<1 :: size(2),
			  msg.type :: size(2),
			  byte_size(msg.token) :: size(4),
			  msg.code,
			  msg.id  :: size(16),
			  msg.token,
			  Coap.Option.to_binary(msg.options),
			  msg.payload
			>>
		end

		@doc "Converts a binary coap message to a message struct."
		def from_binary(pkt) when is_binary pkt do
			<<version :: size(2),
			  type :: size(2),
			  token_length :: size(4),
			  code,
			  message_id  :: size(16),
			  tail :: binary
			>> = pkt

			^version = 1

			token_bit_length = 8 * token_length

			<<token :: [size(token_bit_length), bitstring], tail :: binary >> = tail

			[options, payload] = Coap.Option.from_binary(tail)

			%Message{
				version: version,
				type: type,
				token: token,
				code: code,
				id: message_id,
				options: options,
				payload: payload
			}

		end
		
		@doc "Return the formatted code like '4.04'."
		def render_code(code) do
			class = code_class(code)
			detail = code_detail(code)

			if class == 1 || class > 31 || class < 0 do
				raise("Code Class is out of Bounds")
			end

			if detail > 31 || detail < 0 do
				raise("Code Detail is out of Bounds")
			end

			cond do
				detail < 10 ->
					to_string(code_class(code)) <> ".0" <> to_string(code_detail(code))
				true ->
					to_string(code_class(code)) <> "." <> to_string(code_detail(code))
			end
		end

		@doc "Parse out the code class from a binary code."
		def code_class(code) do
			code >>> 5
		end

		@doc "Parse out the detail class from a binary code."
		def code_detail(code) do
			code &&& (0xFF >>> 3)
		end

		@doc "Encode a code class and code detail into a binary code."
		def gen_code(class, detail) do
			class <<< 5 ||| detail
		end
		
	end

	defmodule Option do
		@moduledoc """
		This module represents a single coap option as well as providing
		encoding and decoding functionality.
		"""
		defstruct number: 0,
		          value: <<>>

		@doc "Converts the option struct to a binary coap option."
		def to_binary(opt, last_option_number) when is_map opt do

			cond do
				opt.number - last_option_number < 0 ->
					raise("Option Delta Cannot be Less than Zero")
				opt.number - last_option_number < 13 ->
					extended_opt_delta = <<>>
					base_opt_delta = opt.number - last_option_number
				opt.number - last_option_number < 269 ->
					extended_opt_delta = <<opt.number - last_option_number - 13>>
					base_opt_delta = 13
				opt.number - last_option_number < 65805 ->
					extended_opt_delta = <<opt.number - last_option_number - 269>>
					base_opt_delta = 14
				true ->
					raise("Option Number Out of Bounds")
			end

			cond do
				byte_size(opt.value) < 13 ->
					extended_opt_len = <<>>
					base_opt_len = byte_size(opt.value)
				byte_size(opt.value) < 269 ->
					extended_opt_len = <<byte_size(opt.value) - 13>>
					base_opt_len = 13
				byte_size(opt.value) < 65805 ->
					extended_opt_len = <<byte_size(opt.value) - 269>>
					base_opt_len = 14
				true ->
					raise("Option Length Out of Bounds")
			end

			<<(base_opt_delta <<< 4) && base_opt_len>> <>
				extended_opt_delta <>
				extended_opt_len <>
				opt.value
		end
		def to_binary([opt_head|opt_tail], last_option_number, opt_binary) do
			this_opt_bin = Option.to_binary(opt_head, last_option_number)
			to_binary(opt_tail, opt_head.number, opt_binary <> <<this_opt_bin>>)
		end
		def to_binary([], _, opt_binary) do
			opt_binary
		end
		def to_binary(options) when is_list options do
			sorted_options = Enum.sort(options, &(&1.number > &2.number))
			to_binary(sorted_options, 0, <<>>)
		end

		@doc "Converts a binary coap option to an option struct."
		def from_binary(pkt)  when is_binary pkt do
			from_binary(pkt, 0, [])
		end
		def from_binary(<<0xFF,  payload :: binary>>, _, opts) when is_list opts do
			[opts, payload]
		end
		def from_binary(<<>>, _, opts) when is_list opts do
			[opts, <<>>]
		end
		def from_binary(<<base_opt_delta :: size(4),
			              base_opt_len :: size(4),
			              tail::binary>>,
			            last_option_number, opts) when is_list opts do


			cond do
				base_opt_delta < 13 ->
					opt_delta = base_opt_delta
				base_opt_delta == 13 ->
					<<extended_opt_delta, tail::binary>> = tail
					opt_delta = extended_opt_delta + 13
				base_opt_delta == 14 ->
					<<opt_delta :: size(16), tail::binary>> = tail
					opt_delta = opt_delta + 269
				base_opt_delta >= 15 ->
					raise("Bad Option Delta")
			end

			cond do
				base_opt_len < 13 ->
					opt_len = base_opt_len
				base_opt_len == 13 ->
					<<extended_opt_len, tail::binary>> = tail
					opt_len = extended_opt_len + 13
				base_opt_len == 14 ->
					<<opt_len :: size(16), tail::binary>> = tail
					opt_len = opt_len + 269
				base_opt_len >= 15 ->
					raise("Bad Option Delta")
			end

			opt_bit_len = 8 * opt_len

			number = opt_delta + last_option_number
			<<value :: [size(opt_bit_len), bitstring], tail :: binary>> = tail

			opts = [%Option{
				number: number,
				value: value
			}] ++ opts

			from_binary(tail, number, opts)
		end
		
	end
	
end

# Example Commands to Try:

#> packet = %Coap.Message{type: 1}
#> Coap.Message.from_binary <<97,69,188,144,112,68>> <> "abcd" <> <<255>> <> "temp = 22.5 C"
#> Coap.Message.from_binary <<64,0,0,0>>