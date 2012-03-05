#Duly Noted
[![Build Status](https://secure.travis-ci.org/willcosgrove/duly_noted.png?branch=master)](http://travis-ci.org/willcosgrove/duly_noted)
Duly noted is a redis backed stats and metrics tracker.  It works as follows:

    DulyNoted.track("page_views", for: "homepage")

This would log one page view for the home page.  Then to see how many page views the home page has gotten, you would simply call:

    DulyNoted.count("page_views", for: "homepage")

You can also store meta data with your metrics by passing your data in a hash to the `meta` key like so:

    DulyNoted.track("page_views", for: "homepage", meta: {user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.121 Safari/535.2", ip_address: "128.194.3.138"})

If the metric was generated in the past but is just now being logged, you can alter it's time stamp with the `generated_at` key:

    DulyNoted.track("page_views", for: "homepage", generated_at: 10.minutes.ago)

To get the count for a particular time range, you can use the `time_start` and `time_end` keys in the count call like so:

    DulyNoted.count("page_views", for: "homepage", time_start: 1.day.ago, time_end: Time.now)

This will return the page view count for the home page for the past day.

###### Not nearly ready for public use, in case there were any questions.

##To Do
* Write tests

* Currently the `:for` key is necessary for most calls, and I'm still in the air on whether it should stay a requirement, or if it should be optional.

  * If it is a requirement, then you could query all page counts easily by not specifying the `:for` key on the count… I'm leaning towards it being a requirement, seems like it would be the case more often than not.

* Count by meta fields: How many page views from each browser?

* A `chart` method which would take a `time_start`, `time_end`, and a `granularity` which would allow you to easily get the per hour for each hour for the past day, for example.

* Maybe some Rails view helpers to generate some code for a Javascript charting library, or Google Charts API.

##Contributing
If you want to help, you should do it.  Fork it, fix it, and send me a pull request.  I will be delighted.