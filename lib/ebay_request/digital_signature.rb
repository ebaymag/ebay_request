# frozen_string_literal: true

# sign data with ebay digital signature method
# https://developer.ebay.com/develop/guides/digital-signatures-for-apis#sigkey
class EbayRequest::DigitalSignature
  class SignatureException < StandardError; end
  SIGNATURE_PARAMS = %w[Content-Digest
                        x-ebay-signature-key
                        @method
                        @path
                        @authority].freeze

  def initialize(url:, config:, headers: {}, body: '', verb: "POST")
    validate_args!(headers: headers, verb: verb, config: config, body: body)

    @config = config
    @config.validate_signature!

    @signature_params = SIGNATURE_PARAMS.dup
    @body = body
    @headers = headers
    @url = URI.parse(url)
    @verb = verb
    @signature_input = "".dup
  end

  def call
    if verb == "POST"
      add_digest_header
    else
      signature_params.delete("Content-Digest")
    end
    add_x_ebay_signature_key
    add_signature_headers
    add_enforce_header

    headers
  end

  private

  def validate_args!(headers:, verb:, config:, body:)
    unless %w[POST GET].include?(verb)
      raise SignatureException, "Invalid verb '#{verb}' use 'POST or GET'"
    end
    raise SignatureException, "Invalid config" unless config.is_a?(EbayRequest::Config)
    raise SignatureException, "Invalid body" unless body.is_a?(String)
    raise SignatureException, "Body can't be blank when verb is POST" if verb == "POST" && body.empty?
    raise SignatureException, "Invalid headers" unless headers.is_a?(Hash)
  end

  attr_reader :body, :headers, :verb,
              :url, :signature_input, :config,
              :signature_params

  def add_enforce_header
    headers["x-ebay-enforce-signature"] = "true"
  end

  def add_digest_header
    content_digest = Base64.encode64(
      OpenSSL::Digest::SHA256.digest(body)
    ).strip

    headers["Content-Digest"] = "sha-256=:#{content_digest}:"
  end

  def add_x_ebay_signature_key
    headers["x-ebay-signature-key"] = x_ebay_signature_key
  end

  def add_signature_headers
    signature = signature_value

    headers["Signature"] = "sig1=:#{signature}:"
    headers["Signature-Input"] = "sig1=#{signature_input}"
  end

  def signature_value
    calculated_string = calculate_base

    pkey = OpenSSL::PKey::RSA.new(private_key)
    signature = pkey.sign(OpenSSL::Digest.new("SHA256"), calculated_string)
    Base64.strict_encode64(signature).strip
  end

  def calculate_base
    buf = "".dup
    signature_params.each do |header|
      buf << "\""
      buf << header.downcase
      buf << "\": "
      if header.start_with?("@")
        case header.downcase
        when "@method"
          buf << verb.to_s
        when "@path"
          buf << url.path.to_s
        when "@authority"
          buf << url.host.to_s
          buf << ":#{url.port}" if url.port != 443 && url.port != 80
        else
          raise SignatureException, "Unknown pseudo header: #{header}"
        end
      else
        raise SignatureException, "Header #{header} not included in message" unless headers[header]

        buf << headers[header]
      end
      buf << "\n"
    end
    buf << "\"@signature-params\": "
    signature_input << "("

    signature_params.each do |header|
      signature_input << "\""
      signature_input << header.downcase
      signature_input << "\""

      signature_input << " " if header != signature_params.last
    end
    signature_input << ")"
    signature_input << ";created=#{Time.now.to_i}"

    buf << signature_input
  end

  def private_key
    config.digital_signature_private_key
  end

  def x_ebay_signature_key
    config.digital_signature_jwe
  end
end
