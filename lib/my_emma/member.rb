module MyEmma

  class Member < RemoteObject

    attr_accessor :email, :status, :member_id

    API_PROTECTED = [:status, :confirmed_opt_in, :account_id, :member_id, :last_modified_at, :member_status_id,
                     :plaintext_preferred, :email_error, :member_since, :bounce_count, :deleted_at]

    SPECIAL_UPDATE_REQUIRED = [:email]

    @@known_attributes = Set.new

    def self.custom_attributes(*symbols)
      legal_symbols = symbols.select {|s| MyEmma.legal?(s) }
      @@known_attributes.merge(legal_symbols)
      legal_symbols.each { |key| self.class_eval do; attr_accessor "#{key}"; end }
      self.methods
    end

    def initialize(attr = {})
      @groups = Array.new
      @drop_groups = Array.new
      @groups_lazy_load_required = true
      attr = Member.load_attributes(attr)
      super(attr)
    end

    def self.find_by_email(email)
      set_http_values
      g = get("/members/email/#{email}")
      if g['error'].blank?
        m = Member.new(g)
      else
        nil
      end
    end

    def self.count
      set_http_values
      c = get("/members?count=true").to_i
    end

    def self.all
      self.get_all_in_slices('/members',Member.count)
    end

    def self.get_all_in_slices(base_url,total)
      set_http_values
      remaining = total
      start_record = 0
      result = Array.new
      end_record = [499, total].min
      while remaining > 0
        members = get("#{base_url}?start=#{start_record}&end=#{end_record}")

        members.each { |m|
           result << Member.new(m)
         }
        remaining = remaining - (end_record - start_record + 1)
        start_record = end_record + 1
        end_record = [start_record + 499, total].min
        puts "new slice: #{start_record}, #{end_record} with #{remaining} left. Parsed #{members.size}"
      end
      result
    end

    def self.find(member_id)
      set_http_values
      g = get("/members/#{member_id}")
      if g['error'].nil?
        Member.new(g)
      else
        nil
      end
    end

    def groups(reload = false)
      if (reload || @groups_lazy_load_required) && !self.member_id.nil?
        @api_groups = Group.find_all_by_member_id(self.member_id)
        @api_groups.each {|g| @groups << g unless @groups.map {|g1| g1.member_group_id }.include?(g.id) }
        @groups_lazy_load_required = false
      end
      @groups
    end

    def add_group(group)
      self.groups << group if group.id.nil? || !@groups.map {|g| g.member_group_id }.include?(group.id)
    end

    def remove_group(group)
      self.groups.delete(group)
      @drop_groups << group
    end

    def save(groups = nil)
      add_to_group_ids = Array.new
      add_to_group_ids = groups.map { |g| if g.is_a? Group
        g.group_member_id
      else
        g.to_i
      end } unless groups.nil?
      @groups.each { |group| group.save if group.member_group_id.nil? }
      response = self.import_single_member(add_to_group_ids)
      raise Net::HTTPBadResponse response['error'] unless response['error'].nil?
      return Member.operation_ok?(response)
    end

    def self.api_attributes
      @@known_attributes
    end

    def active?
      @status == "active"
    end

    protected

    def self.load_attributes(attr)
      if attr.has_key?('fields') then
        attr['fields'].each {|k,v| attr[k] = v}
      end
      new_keys = attr.keys.map { |k| k.to_sym }
      new_keys.delete(:fields)
      @@known_attributes.merge(new_keys)
      @@accessible_attributes = @@known_attributes.clone.subtract(API_PROTECTED)
      attr
    end

    def self.accessible_attributes
      @@accessible_attributes
    end


    def fields
      result = Hash.new
      self.class.accessible_attributes.clone.subtract(SPECIAL_UPDATE_REQUIRED).each {|key|
        result[key] = instance_variable_get "@#{key}"
      }
      result
    end

    def import_single_member(add_to_group_ids = nil)
      Member.set_http_values
      g_ids = @groups.map {|g| g.member_group_id.to_i }
      g_ids = g_ids | add_to_group_ids.map{|g| g.to_i} unless add_to_group_ids.nil?
      response = Member.post("/members/add",
                             :body=>{ :email=>self.email,
                                      :fields=>self.fields,
                                      :status_to=>self.status.nil? ? 'a' : self.status,
                                      :group_ids=>g_ids }.to_json
                             )
      self.member_id = response['member_id'].to_i
      self.status = response['status']
      response
    end

  end

end
