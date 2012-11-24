require 'spec_helper'

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
end