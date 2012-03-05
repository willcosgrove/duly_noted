require 'duly_noted'

describe DulyNoted, "#track" do
  it "logs to redis database" do
    20.times { DulyNoted.track "coke_cans" }
    DulyNoted.count("coke_cans").should eq(20)
  end
end