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
    it "can track past events" do
      DulyNoted.track "page_views", :generated_at => Time.now-10
      DulyNoted.count "page_views", :time_range => Time.now-11..Time.now-9
    end
  end

  describe "#update" do
    it "overwrites duplicate keys" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0}, :ref_id => "unique"
      DulyNoted.update "page_views", "unique", :meta => {:seconds_open => 5}
      DulyNoted.query("page_views").should include({"seconds_open" => "5"})
      DulyNoted.query("page_views").should_not include({"seconds_open" => "0"})
    end
    it "doesn't replace old hash" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0}, :ref_id => "unique"
      DulyNoted.update "page_views", "unique", :meta => {:ip_address => "19.27.182.32"}
      DulyNoted.query("page_views").should include({"seconds_open" => "0", "ip_address" => "19.27.182.32"})
    end
  end

  describe "#query" do
    it "should grab entire meta hash" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.query("page_views").should include({"seconds_open" => "0", "browser" => "chrome"})
    end
    it "can query a certain ref_id" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}, :ref_id => "unique"
      DulyNoted.track "page_views", :meta => {:seconds_open => 10, :browser => "firefox"}
      DulyNoted.query("page_views", :ref_id => "unique").should include({"seconds_open" => "0", "browser" => "chrome"})
      DulyNoted.query("page_views", :ref_id => "unique").should_not include({"seconds_open" => "10", "browser" => "firefox"})
    end
    it "can grab only specific fields from the hash" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.query("page_views", :meta_fields => [:browser]).should include({"browser" => "chrome"})
      DulyNoted.query("page_views", :meta_fields => [:browser]).should_not include({"seconds_open" => "0"})
      DulyNoted.track "downloads", :meta => {:file_name => "rules.pdf", :browser => "chrome"}, :ref_id => "unique"
      DulyNoted.query("downloads", :ref_id => "unique", :meta_fields => [:browser]).should include({"browser" => "chrome"})
      DulyNoted.query("downloads", :ref_id => "unique", :meta_fields => [:browser]).should_not include({"file_name" => "rules.pdf"})
    end
    it "can get only meta hashes from a certain time range" do
      5.times { DulyNoted.track "page_views", :meta => {:seconds_open => 5, :browser => "chrome"} }
      sleep 0.5
      5.times { DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "firefox"} }
      DulyNoted.query("page_views", :time_start => Time.now-0.5, :time_end => Time.now).should include({"seconds_open" => "0", "browser" => "firefox"})
      DulyNoted.query("page_views", :time_range => Time.now-0.5..Time.now).should include({"seconds_open" => "0", "browser" => "firefox"})
      DulyNoted.query("page_views", :time_start => Time.now-0.5, :time_end => Time.now).should_not include({"seconds_open" => "5", "browser" => "chrome"})
      DulyNoted.query("page_views", :time_range => Time.now-0.5..Time.now).should_not include({"seconds_open" => "5", "browser" => "chrome"})
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
      5.times { DulyNoted.track "page_views", :for => "home" }
      5.times { DulyNoted.track "page_views", :for => "contact_us" }
      sleep 0.2
      5.times { DulyNoted.track "page_views", :for => "home" }
      5.times { DulyNoted.track "page_views", :for => "contact_us" }
      DulyNoted.count("page_views", :time_start => Time.now-0.2, :time_end => Time.now).should eq(10)
      DulyNoted.count("page_views", :time_range => Time.now-0.2..Time.now).should eq(10)
    end
  end
end