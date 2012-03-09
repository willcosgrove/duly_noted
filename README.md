#Duly Noted
[![Build Status](https://secure.travis-ci.org/willcosgrove/duly_noted.png?branch=master)](http://travis-ci.org/willcosgrove/duly_noted)

Duly noted is a redis backed stats and metrics tracker.  It works as follows:

    DulyNoted.track("page_views", for: "homepage")

This would log one page view for the home page.  Then to see how many page views the home page has gotten, you would simply call:

    DulyNoted.count("page_views", for: "homepage")
    
To count how many page views there have been across all pages, you can call:

	DulyNoted.count("page_views")

You can also store meta data with your metrics by passing your data in a hash to the `meta` key like so:

    DulyNoted.track("page_views", for: "homepage", meta: {user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.121 Safari/535.2", ip_address: "128.194.3.138"})

If the metric was generated in the past but is just now being logged, you can alter it's time stamp with the `generated_at` key:

    DulyNoted.track("page_views", for: "homepage", generated_at: 10.minutes.ago)

To get the count for a particular time range, you can use the `time_start` and `time_end` keys in the count call like so:

    DulyNoted.count("page_views", for: "homepage", time_start: 1.day.ago, time_end: Time.now)

You can also just specify a `time_range` like so:

    DulyNoted.count("page_views", for: "homepage", time_range: 1.day.ago..Time.now)

This will return the page view count for the home page for the past day.

There are a few other things it can do, check out the [docs]("http://willcosgrove.github.com/duly_noted") for more info.

##Install

You probably already guessed it, but to install just

    gem install duly_noted

or add 

    gem 'duly_noted'

to your `gemfile` and run `bundle install`

##What's New

### 1.0.0
* `for` is no longer required on `count` and `query`.  If you call one of them without `for` it will count all of whatever metric you specified
* Added the `chart` method, which allows you to pull out your data in a handy way that's perfect for giving it to a charting library
* Now pipelines all of the keys that are set in the `track` method
* Added errors so that you know when something's gone wrong!
* Added the Updater which will do redis schema upgrades automatically when duly_noted does another major upgrade
* A special `count_x_by_y` dynamic method.  Say you've tracked page views, and in the meta hash, you've stored their browser name.  Now you want a breakdown of page views by browser, well… `DulyNoted.count_page_views_by_browser` would do just that.  Yay metaprogramming!
* Added the ability to expire `ref_id`s.  So if you know that you'll only need to edit your metadata for, say, the next 10 minutes, you can set the `editable_for` options to `10.minutes` in the `track`, or in the `update` method.  By default, `ref_id`s never expire.
* Some other little behind the scenes methods to help for the big surprise in 1.5.0

### 0.1.0

* Added the `time_range` option to `count`, and `query`

* Added the `meta_fields` option to `query`, which takes an array of fields to pull out from the meta hash

* Added the `ref_id` option to `query`, which takes a reference id and will return an array with one meta hash.  I was going back and forth on whether or not it should wrap the hash in an array.  It doesn't need to be, but I thought, just to make it consistent with it's usual output, I should make it return an array.

* Enough bug fixes to make it production ready! Yay!


##What's Gonna Be New

###1.5.0
* A sinatra app to view and peruse your metrics (think, resque)
* Resolution decay: currently, duly_noted stores all metrics at the highest resolution, timestamped down to a fraction of a second.  With resolution decay, you can specify fall offs so that after, say, a month, they'll be grouped by day.  So after a month has passed, you couldn't go back to a day and see it by hour, only total for that day.  This will tremendously cut back on space, and is, of course, totally customizable. 


##Contributing
If you want to help, you should do it.  Fork it, fix it, and send me a pull request.  I will be delighted.