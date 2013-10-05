require 'date'
require 'event'
require 'event_collection'

describe GithubDashing::EventCollection do

  it "fills empty months in group_by_month" do
    collection = GithubDashing::EventCollection.new
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,01,20)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,03,20)})
    grouped = collection.group_by_month DateTime.new(2012,12,20)
    grouped.keys[0].should eq '2012-12'
    grouped.keys.should include '2012-12'
    grouped.keys.should include '2013-01'
    grouped.keys.should include '2013-02'
    grouped.keys.should include '2013-03'
  end

  it "groups events by month in group_by_month" do
    collection = GithubDashing::EventCollection.new
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,01,15)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,01,20)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,03,20)})
    grouped = collection.group_by_month DateTime.new(2012,12,20)
    grouped['2013-01'].count.should eq 2
    grouped['2013-02'].count.should eq 0
    grouped['2013-03'].count.should eq 1
  end

  it "excludes out of range events from collection in group_by_month" do
    collection = GithubDashing::EventCollection.new
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,01,20)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,02,20)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,03,20)})
    collection << GithubDashing::Event.new({datetime: DateTime.new(2013,04,20)})
    grouped = collection.group_by_month(DateTime.new(2013,02,01), DateTime.new(2013,03,01))
    grouped.keys.should_not include '2013-01'
    grouped.keys.should include '2013-02'
    grouped.keys.should include '2013-03'
    grouped.keys.should_not include '2013-04'
  end

end