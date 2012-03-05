require 'spec_helper'

describe DulyNoted do
  before :each do
    DulyNoted.redis.flushall
  end
  describe "#track" do
    it "keeps an accurate count of events" do
      2.times { DulyNoted.track "page_views" }
      DulyNoted.count("page_views").should eq(2)
    end
    it "separates by context" do
      2.times { DulyNoted.track "page_views", :for => "home" }
      5.times { DulyNoted.track "page_views", :for => "contact_us" }
      DulyNoted.count("page_views", :for => "home").should eq(2)
      DulyNoted.count("page_views", :for => "contact_us").should eq(5)
    end
    it "stores metadata" do
      DulyNoted.track "page_views", :meta => {:open => true}
      DulyNoted.query("page_views").should include({"open" => "true"})
    end
  end
  describe "#update" do
    it "overwrites old values" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0}, :ref_id => "unique"
      DulyNoted.update "page_views", "unique", :meta => {:seconds_open => 5}
      DulyNoted.query("page_views").should include({"seconds_open" => "5"})
      DulyNoted.query("page_views").should_not include({"seconds_open" => "0"})
    end
  end
  describe "#count" do
    it "can count events in between a time range" do
      5.times { DulyNoted.track "page_views" }
      sleep 0.2
      5.times { DulyNoted.track "page_views" }
      DulyNoted.count("page_views", :time_start => Time.now-0.2, :time_end => Time.now).should eq(5)
      DulyNoted.count("page_views", :time_range => Time.now-0.2..Time.now).should eq(5)
    end
    it "can count all of one type of metric" do
      5.times { DulyNoted.track "page_views", :for => "home" }
      5.times { DulyNoted.track "page_views", :for => "contact_us" }
      DulyNoted.count("page_views").should eq(10)
    end
    it "can count all of one type between a time range" do
      5.times { DulyNoted.track "page_views", for: "home" }
      5.times { DulyNoted.track "page_views", for: "contact_us" }
      sleep 0.2
      5.times { DulyNoted.track "page_views", for: "home" }
      5.times { DulyNoted.track "page_views", for: "contact_us" }
      DulyNoted.count("page_views", :time_start => Time.now-0.2, :time_end => Time.now).should eq(10)
      DulyNoted.count("page_views", :time_range => Time.now-0.2..Time.now).should eq(10)
    end
  end
end