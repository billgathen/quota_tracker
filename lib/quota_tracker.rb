module QuotaTracker
  require 'savon'

  class Client
    attr_reader :domain
    TestDomain = "https://api-test.yieldmanager.com"
    ProductionDomain = "https://api.yieldmanager.com"

    CommandGroups = {
      "AccountManagement" => { :service => :contact, :method => :getSelf, :args => {} }, # Contact, Entity
  #    "BillingAndPayments" => {}, # Adjustment: never used
      "Creatives" => { :service => :creative, :method => :listByEntity, :args => { "campaign_id" => -1 } }, # Creative (except add, addCreatives and addSupportingFiles)
      "CreativeUpload" => { :service => :creative, :method => :addCreatives, :args => { "creatives" => [] } }, # Creative (add, addCreatives and addSupportingFiles)
      "Inventory" => { :service => :site, :method => :listByEntity, :args => { "entity_id" => 3 } }, # Section, Site
      "NetworkManagement" => { :service => :dictionary, :method => :getNetspeeds, :args => {} }, # Dictionary, Linking, Notification, Pixel and Search
      "Orders" => { :service => :campaign, :method => :listByEntity, :args => { "entity_id" => 3 } }, # Campaign, InsertionOrder, LineItem, TargetProfile
      "Reports" => { :service => :report, :method => :status, :args => { "report_token" => 1 } }, # ReportService (except opportunityRequestViaXML)
  #    "OpportunityReports" => {} # ReportService#opportunityRequestViaXML: never used
    }

    ServicesByCommandGroup = {
      "AccountManagement" => ["contact", "entity"],
      "Creatives" => ["creative"], # (except add, addCreatives and addSupportingFiles)
      "CreativeUpload" => ["creative"], # (add, addCreatives and addSupportingFiles)
      "Inventory" => ["section", "site"],
      "NetworkManagement" => ["dictionary", "linking", "notification", "pixel", "search"],
      "Orders" => ["campaign", "insertion_order", "line_item", "target_profile"],
      "Reports" => ["report"] # (except opportunityRequestViaXML)
    }

    LoginOptions = {
      :errors_level => 'throw_errors',
      :multiple_sessions => '1'
    }

    def self.system_check env = "prod"
      qt = QuotaTracker::Client.new({
        :user => ENV['YIELDMANAGER_USER'],
        :pass => ENV['YIELDMANAGER_PASS'],
        :version => ENV['YIELDMANAGER_API_VERSION'],
        :env => env
      })
      puts
      puts "Running against #{qt.domain}"
      puts
      puts sprintf('%20s%20s','Command Group','Daily Quota')
      puts "-" * 40
      quotas = qt.get_quota_for_cmd_groups
      quotas.keys.sort.each do |group|
        puts sprintf('%20s%20d', group, quotas[group])
      end
      puts
      usage = qt.get_usage_for_all
      puts sprintf('%20s%10s%10s','Command Group','Used','Remaining')
      puts "-" * 40
      usage.keys.sort.each do |group|
        stats = usage[group]
        puts sprintf('%20s%10d%10d %s', group, stats[:quota_used_so_far] || 0, stats[:remaining_quota] || 0, stats[:error])
      end
      puts
    end

    def initialize(login_args = {})
      fail "Please supply hash containing :user, :pass and :version" unless login_args[:user] && login_args[:pass] && login_args[:version]
      @user = login_args[:user]
      @pass = login_args[:pass]
      @version = login_args[:version]
      if login_args[:env] && login_args[:env].downcase == "test"
        @domain = TestDomain
      else
        @domain = ProductionDomain
      end
    end

    def command_groups
      CommandGroups.keys.sort
    end

    def services_by_command_group name
      ServicesByCommandGroup[name]
    end

    def be_quiet
      HTTPI.log = false
      Savon.configure do |config|
        config.log = false # disable logging
        config.log_level = :info
        # config.logger = Rails.logger
      end
    end

    def build_client(name)
      version = @version # can't see instance variables within config block
      path = "#{@domain}/api-#{version}/#{name}.php?wsdl"
      Savon::Client.new { wsdl.document = path }
    end

    def login(contact)
      # can't see instance variables within config block
      user = @user
      pass = @pass
      rsp = contact.request :login do
        soap.body = { :user => user, :pass => pass, :login_options => LoginOptions }
      end
      token = rsp.to_hash[:login_response][:token]
      token
    end

    def logout(contact, token)
      contact.request :logout do
        soap.body = { :token => token }
      end
    end

    def session
      be_quiet
      contact = build_client("contact")
      token = login(contact)
      begin
        yield token
      ensure
        logout contact, token
      end
    end

    def get_entity id
      session do |token|
        entity = build_client("entity")
        rsp = entity.request :get do
          soap.body = { :token => token, :id => id }
        end
        hdr = rsp.header
        entity = rsp.to_hash[:get_response][:entity]
  #      puts "#{hdr[:command_group]} #{hdr[:quota_type]} quota: #{hdr[:quota_used_so_far]} used, #{hdr[:remaining_quota]} remaining"
  #      puts "#{entity[:name]} (#{entity[:id]})"
        entity
      end
    end

    def get_quota_for_cmd_groups
      quotas = {}
      session do |token|
        client = build_client("quota")
        command_groups.each do |group|
          quotas[group] = get_quota_for_cmd_group client, token, group
        end
      end
      quotas
    end

    def get_quota_for_cmd_group client, token, group
      rsp = client.request :getQuotaByCmdGroup do
        soap.body = { :token => token, "cmdgroup_name" => group }
      end
      rsp_hash = rsp.to_hash[:get_quota_by_cmd_group_response][:quota]
      rsp_hash[:item][:limit]
    end

    def get_usage_for_service svc, mthd, args = {}
      session do |t|
        begin
          svc_client = build_client(svc)
          rsp = svc_client.request mthd do
            soap.body = { :token => t }.merge(args)
          end
          rsp.header
        rescue => e
          #puts "#{svc}.#{mthd} #{e.message}"
          {:error => e.message}
        end
      end
    end

    def get_usage_for_method(svc, mthd)
      results = {}
      session do |token|
        quota_client = build_client("quota")
        rsp = quota_client.request :getQuotaByServiceByMethod do
          soap.body = { :token => token, "service_name" => svc, "service_method" => mthd }
        end
        results = rsp.to_hash[:get_quota_by_service_by_method_response][:quota][:item]
      end
      results
    end

    def get_usage_for_all
      usage = {}
      CommandGroups.each do |group, lookup|
        usage[group] = get_usage_for_service(lookup[:service], lookup[:method], lookup[:args])
      end
      usage
    end

    def get_methods_for_service(service_name)
      session do |t|
        svc = build_client(service_name)
        svc.wsdl.soap_actions.map{|a| to_camelcase(a.to_s) }.sort
      end
    end

    def to_camelcase str
      str.nil? ? str : str.gsub(/(_)(.)/) { |s| $2.upcase }
    end
  end
end
