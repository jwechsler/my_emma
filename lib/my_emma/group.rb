module MyEmma
  class Group < RemoteObject

    API_ACCESSIBLE = [ :active_count, :group_type, :group_name ]

    API_PROTECTED = [:deleted_at, :error_count, :optout_count, :member_group_id, :account_id ]

    API_ATTRIBUTES = API_ACCESSIBLE + API_PROTECTED

    DYNAMIC_ATTRIBUTES = false

    attr_accessor :group_name
    attr_reader :member_group_id

    def initialize( attr = {})
      super(attr)
    end

    def id
      self.member_group_id
    end

    def self.all(options = {})
      set_http_values
      groups = get('/groups', options)
      found = []
      groups.each {|g| found << Group.new(g)} if self.operation_ok?(groups)
      found
    end

    def copy_members_to_group(group_id)
      Group.set_http_values
      response = Group.put("/groups/#{self.id}/#{group_id}/members/copy", :body=>{member_status_id: ['a','e','o']}.to_json)
      result = Group.operation_ok?(response)
    end

    def self.find(member_group_id)
      set_http_values
      g = get("/groups/#{member_group_id}")
      Group.new(g)
    end

    def self.find_by_group_name(group_name, options={})
      candidates = all(options)
      candidates.select { |g| g.group_name == group_name}.first
    end

    def self.find_all_by_member_id(member_id)
      result = Array.new
      groups = Member.get("/members/#{member_id}/groups")
      groups.each { |g| result << Group.new(g) }
      result
    end

    def remove_members(m)
      if m.is_a? Array
        members = m
      else
        members = [m]
      end
      Group.set_http_values
      response = Group.put("/groups/#{self.member_group_id}/members/remove", :body=> {:member_ids=>members.map{|member| member.member_id}}.to_json)
      result = Group.operation_ok?(response)
    end

    def members
      Member.get_all_in_slices("/groups/#{self.member_group_id}/members", self.active_count+self.optout_count+self.error_count)
    end


    def save
      if self.persisted?
        self.update
      else
        self.create
      end
    end

    def self.api_attributes
      API_ATTRIBUTES
    end


    protected

    def self.accessible_attributes
      API_ACCESSIBLE
    end

    def accessible_to_hash
      result = {}
      API_ACCESSIBLE.each do |key|
        result[key] = instance_variable_get("@#{key}") if self.respond_to? key
      end
      result
    end


    def create
      Group.set_http_values
      response = Group.post('/groups', :body=> {:groups=>[self.accessible_to_hash]}.to_json)
      result = Group.operation_ok?(response)
      @member_group_id = response[0]['member_group_id'] if result
      result
    end

    def update
      Group.set_http_values
      response = Group.put("/groups/#{self.member_group_id}", :body=> {:group_name => self.group_name})
      Group.operation_ok?(response)
    end

  end
end
