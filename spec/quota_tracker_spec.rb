require 'quota_tracker'

describe QuotaTracker do
  before do
    @login_args = {
      :user => ENV['YIELDMANAGER_USER'],
      :pass => ENV['YIELDMANAGER_PASS'],
      :version => ENV['YIELDMANAGER_API_VERSION']
    }
#    @qt = QuotaTracker::Client.new(@login_args.merge(:env => "test"))
    @qt = QuotaTracker::Client.new(@login_args)
  end

  describe "setup" do
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
  end

  describe "quota" do
    it "returns for all command groups" do
      quotas = @qt.get_quota_by_cmd_group
      quotas.keys.sort.should == @qt.command_groups
      quotas.each do |group, quota|
  #      puts "#{group}: #{quota}"
        quota.to_i.should > 0 # non-number or nil converts to zero
      end
    end
  end

  describe "usage pulls" do
    it "for single command group" do
      usage = @qt.get_usage_for_service("contact", :getSelf)
      usage.should_not be_nil
      usage[:command_group].should == "AccountManagement"
      usage[:quota_used_so_far].should_not be_nil
      usage[:remaining_quota].should_not be_nil
    end

    it "for all command groups" do
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
        puts "#{group}: #{stats[:quota_used_so_far]} used, #{stats[:remaining_quota]} remaining"
      end
    end

    it "by method" do
      usage = @qt.get_usage_for_method("EntityService","getAll")
      usage.should_not be_nil
      usage.size.should > 0
      usage[:service].should == "EntityService"
      usage[:method].should == "getAll"
      usage[:used].to_i.should > -1 # could be zero if not used today
#      puts "#{usage[:service]}.#{usage[:method]}: #{usage[:used]} used today"

      usage = @qt.get_usage_for_method("ContactService","login")
      usage.should be_nil # method is outside quota system, so it returns nothing
    end

    it "by all methods for a service" do
      pending
      svc = "campaign"
      methods = @qt.get_methods_for_service(svc)
      methods.each_with_index do |mthd,idx|
        usage = @qt.get_usage_for_method(@qt.to_camelcase(svc).capitalize + "Service",mthd)
        puts "[#{idx+1} of #{methods.size}] #{usage[:service]}.#{usage[:method]}: #{usage[:used]} used today"
      end
    end
  end

  describe "lookup" do
    it "services by command group" do
      services = ["dictionary", "linking", "notification", "pixel", "search"]
      command_group = "NetworkManagement"
      @qt.services_by_command_group(command_group).should == services
    end

    it "methods by service" do
      contact_methods = [
        "add",
        "changePassword",
        "delete",
        "get",
        "getActiveSessions",
        "getAll",
        "getAllSince",
        "getByEntity",
        "getSelf",
        "listAll",
        "listAllDeletedSince",
        "listAllSince",
        "listByEntity",
        "login",
        "logout",
        "logoutAll",
        "setPassword",
        "update",
        "validateCredentials"
      ]
      found_methods = @qt.get_methods_for_service("contact")
      found_methods.sort.should == contact_methods
    end
  end

  describe "converts" do
    it "snake_case to camelCase" do
      @qt.to_camelcase(nil).should == nil
      @qt.to_camelcase("").should == ""
      @qt.to_camelcase("get").should == "get"
      @qt.to_camelcase("get_all").should == "getAll"
      @qt.to_camelcase("list_by_entity").should == "listByEntity"
    end
  end
end
