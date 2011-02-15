require 'quota_tracker'

describe QuotaTracker do
  before do
    @login_args = {
      :user => ENV['YIELDMANAGER_USER'],
      :pass => ENV['YIELDMANAGER_PASS'],
      :version => ENV['YIELDMANAGER_API_VERSION']
    }
    @qt = QuotaTracker::Client.new(@login_args.merge(:env => "test"))
  end

  it "complains when created without user/pass" do
    lambda{ QuotaTracker::Client.new() }.should raise_error("Please supply hash containing :user, :pass and :version")
  end

  it "defaults to production" do
    @qt_prod = QuotaTracker::Client.new(@login_args)
    @qt_prod.domain.should == "https://api.yieldmanager.com"
  end

  it "runs in test on request" do
    @qt_test = QuotaTracker::Client.new(@login_args.merge(:env => "test"))
    @qt_test.domain.should == "https://api-test.yieldmanager.com"
  end

  it "returns quota usage for AccountManagement command group" do
    usage = @qt.get_usage_for_service("contact", :getSelf)
    usage.should_not be_nil
    usage[:command_group].should == "AccountManagement"
    usage[:quota_used_so_far].should_not be_nil
    usage[:remaining_quota].should_not be_nil
  end

  it "returns quota for all command groups" do
    quotas = @qt.get_quota_by_cmd_group
    quotas.keys.sort.should == @qt.command_groups
    quotas.each do |group, quota|
#      puts "#{group}: #{quota}"
      quota.to_i.should > 0 # non-number or nil converts to zero
    end
  end

  it "returns quota usage for all command groups" do
    usage = @qt.get_usage_for_all
    usage.should_not be_nil
    usage.keys.sort.should == @qt.command_groups
    usage.keys.sort.each do |group|
      stats = usage[group]
      stats.should_not be_nil
      stats[:command_group].should == group
      stats[:quota_used_so_far].to_i.should > 0
      stats[:remaining_quota].to_i.should > 0
      stats[:quota_type].should == "daily"
#      puts "#{group}: #{stats[:quota_used_so_far]} used, #{stats[:remaining_quota]} remaining"
    end
  end
end
