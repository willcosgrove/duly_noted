require 'spec_helper'

describe DulyNoted do
  before :each do
    DulyNoted.redis.flushdb
    Timecop.return
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
    it "can nest context" do
      2.times { DulyNoted.track "views", :for => ["user_123", "video_8172"] }
      2.times { DulyNoted.track "views", :for => ["user_123", "video_8173"] }
      DulyNoted.count("views", :for => "user_123").should eq(4)
      DulyNoted.count("views", :for => ["user_123", "video_8173"]).should eq(2)
    end
    it "stores metadata" do
      DulyNoted.track "page_views", :meta => {:open => true}
      DulyNoted.query("page_views").should include({"open" => "true"})
    end
    it "can track past events" do
      Timecop.freeze
      DulyNoted.track "page_views", :generated_at => Time.now-10
      DulyNoted.count "page_views", :time_range => Time.now-11..Time.now-9
    end
  end

  describe "#update" do
    it "overwrites duplicate keys" do
      id = DulyNoted.track "page_views", :meta => {:seconds_open => 0}
      DulyNoted.update id, :meta => {:seconds_open => 5}
      DulyNoted.query("page_views").should include({"seconds_open" => "5"})
      DulyNoted.query("page_views").should_not include({"seconds_open" => "0"})
    end
    it "doesn't replace old hash" do
      id = DulyNoted.track "page_views", :meta => {:seconds_open => 0}
      DulyNoted.update id, :meta => {:ip_address => "19.27.182.32"}
      DulyNoted.query("page_views").should include({"seconds_open" => "0", "ip_address" => "19.27.182.32"})
    end
    it "does not require that `for:` be set to update" do
      id = DulyNoted.track "page_views", :for => "home", :meta => {:seconds_open => 0}
      DulyNoted.update id, :meta => {:seconds_open => 5}
      DulyNoted.query("page_views").should include({"seconds_open" => "5"})
    end
  end

  describe "#query" do
    it "should grab entire meta hash" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.query("page_views").should include({"seconds_open" => "0", "browser" => "chrome"})
    end
    it "can query a certain id" do
      id = DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.track "page_views", :meta => {:seconds_open => 10, :browser => "firefox"}
      DulyNoted.query("page_views", :id => id).should include({"seconds_open" => "0", "browser" => "chrome"})
      DulyNoted.query("page_views", :id => id).should_not include({"seconds_open" => "10", "browser" => "firefox"})
    end
    it "can grab only specific fields from the hash" do
      DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.query("page_views", :meta_fields => [:browser]).should include({"browser" => "chrome"})
      DulyNoted.query("page_views", :meta_fields => [:browser]).should_not include({"seconds_open" => "0"})
      DulyNoted.track "downloads", :meta => {:file_name => "rules.pdf", :browser => "chrome"}, :ref_id => "unique"
      DulyNoted.query("downloads", :ref_id => "unique", :meta_fields => [:browser]).should include({"browser" => "chrome"})
      DulyNoted.query("downloads", :ref_id => "unique", :meta_fields => [:browser]).should_not include({"file_name" => "rules.pdf"})
    end
    it "can grab only specific fields from a certain context from the hash" do
      DulyNoted.track "page_views", :for => "home", :meta => {:seconds_open => 0, :browser => "chrome"}
      DulyNoted.query("page_views", :for => "home", :meta_fields => [:browser]).should include({"browser" => "chrome"})
    end
    it "can get only meta hashes from a certain time range" do
      Timecop.freeze
      5.times { DulyNoted.track "page_views", :meta => {:seconds_open => 5, :browser => "chrome"}, :generated_at => Time.now-1 }
      5.times { DulyNoted.track "page_views", :meta => {:seconds_open => 0, :browser => "firefox"} }
      DulyNoted.query("page_views", :time_start => Time.now-0.5, :time_end => Time.now).should include({"seconds_open" => "0", "browser" => "firefox"})
      DulyNoted.query("page_views", :time_range => Time.now-0.5..Time.now).should include({"seconds_open" => "0", "browser" => "firefox"})
      DulyNoted.query("page_views", :time_start => Time.now-0.5, :time_end => Time.now).should_not include({"seconds_open" => "5", "browser" => "chrome"})
      DulyNoted.query("page_views", :time_range => Time.now-0.5..Time.now).should_not include({"seconds_open" => "5", "browser" => "chrome"})
    end
  end

  describe "#count" do
    it "can count events in between a time range" do
      5.times { DulyNoted.track "page_views", :generated_at => Time.now-1 }
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
      5.times { DulyNoted.track "page_views", :for => "home", :generated_at => Time.now-1 }
      5.times { DulyNoted.track "page_views", :for => "contact_us", :generated_at => Time.now-1 }
      5.times { DulyNoted.track "page_views", :for => "home" }
      5.times { DulyNoted.track "page_views", :for => "contact_us" }
      DulyNoted.count("page_views", :time_start => Time.now-0.2, :time_end => Time.now).should eq(10)
      DulyNoted.count("page_views", :time_range => Time.now-0.2..Time.now).should eq(10)
    end
  end

  describe "#chart" do
    it "should count by a specified time step and store the results in a hash" do
      # Timecop.freeze
      1.times { DulyNoted.track "page_views", :generated_at => Time.now-(2.9) }
      2.times { DulyNoted.track "page_views", :generated_at => Time.now-(1.9) }
      3.times { DulyNoted.track "page_views", :generated_at => Time.now-(0.9) }
      DulyNoted.chart("page_views", :time_range => Time.now-(3)..Time.now-(1), :step => (1)).should have_at_least(3).items
      DulyNoted.chart("page_views", :time_range => Time.now-(3)..Time.now-(1), :step => (1)).should eq({(Time.now-3).to_i => 1, (Time.now-2).to_i => 2, (Time.now-1).to_i => 3})
    end
    it "can count events between a time range, without a step set" do
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 12:30pm")
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 1:20pm")
      DulyNoted.chart("page_views", :time_range => Chronic.parse("yesterday at 12pm")...Chronic.parse("yesterday at 2pm"), :data_points => 2).should eq({Chronic.parse("yesterday at 12pm").to_i => 1, Chronic.parse("yesterday at 1pm").to_i => 1})
    end
    it "will take time_start, step, and data_points options to build a chart" do
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 12:30pm")
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 1:20pm")
      DulyNoted.chart("page_views", :time_start => Chronic.parse("yesterday at 12pm"), :step => (3600), :data_points => 2).should eq({Chronic.parse("yesterday at 12pm").to_i => 1, Chronic.parse("yesterday at 1pm").to_i => 1})
    end
    it "will take time_end, step, and data_points options to build a chart" do
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 12:30pm")
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 1:20pm")
      DulyNoted.chart("page_views", :time_end => Chronic.parse("yesterday at 2pm"), :step => (3600), :data_points => 2).should eq({Chronic.parse("yesterday at 2pm").to_i => 1, Chronic.parse("yesterday at 1pm").to_i => 1})
    end
    it "should raise InvalidStep if you give it a step of zero" do
      DulyNoted.track "page_views"
      expect { DulyNoted.chart("page_views", :time_end => Time.now, :step => 0, :data_points => 2) }.to raise_error(DulyNoted::InvalidStep)
    end
    it "should raise InvalidOptions if you give it invalid options" do
      DulyNoted.track "page_views"
      expect { DulyNoted.chart("page_views", :time_end => Time.now, :step => 60*60) }.to raise_error(DulyNoted::InvalidOptions)
    end
    it "should chart everything if no time range is specified" do
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 12:30pm")
      DulyNoted.track "page_views", :generated_at => Chronic.parse("yesterday at 1:20pm")
      DulyNoted.chart("page_views", :data_points => 2).should eq({Chronic.parse("yesterday at 12:30pm").to_i => 1, Chronic.parse("yesterday at 12:55pm").to_i => 1})
    end
  end

  describe "#metrics" do
    it "should list all currently tracking metrics" do
      DulyNoted.track "page_views"
      DulyNoted.metrics.should include("dn:pageviews")
    end
  end

  describe "#valid_metric?" do
    it "should determine if metric is valid" do
      DulyNoted.track "page_views"
      DulyNoted.valid_metric?("page_views").should be_true
      DulyNoted.valid_metric?("kdfsjhfs").should be_false
    end
  end

  describe "#fields_for" do
    it "should list the stored meta fields for a given metric" do
      DulyNoted.track "page_views", :for => "home", :meta => {:seconds_open => 5, :browser => "chrome"}
      DulyNoted.fields_for("page_views").should include("seconds_open", "browser")
    end
  end

  describe "#count_x_by_y" do
    it "should count x by y" do
      5.times { DulyNoted.track "page_views", :for => "home", :meta => {:browser => "chrome"} }
      5.times { DulyNoted.track "page_views", :for => "contact_us", :meta => {:browser => "firefox"} }
      DulyNoted.count_page_views_by_browser.should eq({"chrome" => 5, "firefox" => 5})
      DulyNoted.count_page_views_by_browser(:for => "home").should eq({"chrome" => 5})
    end
    it "should raise NotValidMetric if the metric is not valid" do
      DulyNoted.track "page_views", :meta => {:browser => "chrome"}
      expect { DulyNoted.count_downloads_by_browser }.to raise_error(DulyNoted::NotValidMetric)
    end
  end

  describe "#sum_meta_field" do
    it "should return the sum of the meta field in the set" do
      5.times { DulyNoted.track "timed_page_views", :for => "home", :meta => {:duration => 10} }
      5.times { DulyNoted.track "timed_page_views", :for => "contact_us", :meta => {:duration => 10} }

      DulyNoted.sum_meta_field('timed_page_views', :duration).should == 100
      DulyNoted.sum_meta_field('timed_page_views', :duration, {:for => 'home'}).should == 50
    end
  end


  describe "#check_schema" do
    it "should update the database if the schema is off by a major release" do
      DulyNoted::VERSION = "2.0.0"
      DulyNoted.redis = nil # Force a reset of the redis instance variable
      DulyNoted.track "page_views"
      DulyNoted.redis.get("dn:version").should eq("2.0.0")
    end
  end
end