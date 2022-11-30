# frozen_string_literal: true

require "spec_helper"

describe EbayRequest::DigitalSignature do
  subject { described_class.new(params) }
  let(:config) do
    EbayRequest::Config.new.tap do |c|
      c.appid = "1"
      c.certid = "2"
      c.devid = "3"
      c.runame = "4"
      c.digital_signature_jwe = "5"
      c.digital_signature_private_key = File.read("spec/fixtures/digital_signature/private_key.txt")
    end
  end

  let(:params) do
    {
      config: config,
      url: "https://api.ebay.com/ws/api.dll",
      verb: "POST",
      body: "{\"hello\": \"world\"}",
      headers: { "Content-Type" => "application/json" },
    }
  end
  context "success" do
    let(:result) do
      JSON.parse(File.read("spec/fixtures/digital_signature/success.json"))
    end

    it "generates signature" do
      allow(Time).to receive(:now).and_return(Time.parse("2019-01-01 00:00:00 UTC"))
      expect(subject.call).to eq(result)
    end
  end

  context "failure" do
    it "invalid config" do
      params[:config] = "invalid"

      expect { subject.call }
        .to raise_error(described_class::SignatureException, "Invalid config")
    end

    it "invalid verb" do
      params[:verb] = "invalid"

      expect { subject.call }
        .to raise_error(
          described_class::SignatureException,
          "Invalid verb 'invalid' use 'POST or GET'"
        )
    end

    it "invalid headers" do
      params[:headers] = "invalid headers"

      expect { subject.call }
        .to raise_error(
          described_class::SignatureException, "Invalid headers"
        )
    end

    it "invalid body" do
      params[:body] = 123

      expect { subject.call }
        .to raise_error(
          described_class::SignatureException, "Invalid body"
        )
    end

    it "body can't be blank when verb is POST" do
      params[:body] = ""

      expect { subject.call }
        .to raise_error(
          described_class::SignatureException,
          "Body can't be blank when verb is POST"
        )
    end
  end
end
