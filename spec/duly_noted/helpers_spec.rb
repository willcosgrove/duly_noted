require 'spec_helper'
require 'base64'

describe DulyNoted::Helpers do
  before :each do
    DulyNoted.redis.flushdb
  end

  describe "#find_keys" do
    before do
      DulyNoted.track "pageviews", :for => ["users", "1"]
      DulyNoted.track "pageviews", :for => ["users", "2"]
    end

    it "should find keys by their prefix" do
      DulyNoted.find_keys("dn:pageviews:users").sort.should == ["dn:pageviews:users:1", "dn:pageviews:users:2"]
    end

    it "should not find a key if it is only matching a prefix partially" do
      DulyNoted.find_keys("dn:pageviews:user").should == []
    end

    it "should find a key when matching exactly" do
      DulyNoted.find_keys("dn:pageviews:users:1").should == ["dn:pageviews:users:1"]
    end
  end

  describe "#normalize" do
    it "should allow base64 encoded content" do
      encoded = Base64.encode64("http://google.de")
      Base64.decode64(DulyNoted.normalize(encoded)).should == "http://google.de"
    end

    it "should handle symbols" do
      DulyNoted.normalize(:sym).should == "sym"
    end

    it "should handle integers" do
      DulyNoted.normalize(1).should == "1"
    end
  end
end