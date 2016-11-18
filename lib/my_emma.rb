require "my_emma/version"
require "my_emma/remote_object"
require "my_emma/group"
require "my_emma/member"
require 'json'
require 'httparty'


module MyEmma

  def self.legal?(attr)
    #Rails.logger.info "Found key #{key}.  It's #{!(key.include?('-')|| key.include?(' ')) ? 'legal' : 'not legal'}"
    return !(key.include?('-'))
  end

   def self.root
    File.expand_path '../..', __FILE__
  end


  def self.set_credentials(username, password, account_id)
    @@username = username
    @@password = password
    @@account_id = account_id
  end

  def self.set_credentials_from_yaml(file)
    values = YAML::load(File.open(file))
    set_credentials(values['username'],values['password'],values['account_id'])
  end

  if !defined? (::Rails)
    set_credentials_from_yaml("#{self.root.to_s}/config/test_credentials.yml")
    #@@username = '89a1c1a1bc1d17da699e'
    #@@password = '638eb64020106e4d5135'
    #@@account_id = 1402458

  end

  def self.initialize_emma_objects
    Group.basic_auth @@username, @@password
    Group.base_uri
  end


  def self.username
    @@username
  end

  def self.password
    @@password
  end

  def self.account_id
    @@account_id
  end

  def self.base_uri
    "https://api.e2ma.net/#{@@account_id}"
  end

  def self.disable
    @@account_id = nil
  end

  def self.disabled?
    @@account_id.blank?
  end

end
