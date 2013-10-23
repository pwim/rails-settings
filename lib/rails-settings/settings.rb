class Settings < ActiveRecord::Base
  class SettingNotFound < RuntimeError; end
  
  def self.defaults
    Thread.current[:rails_settings_defaults] ||= {}.with_indifferent_access
  end
  
  def self.defaults=(value)
    Thread.current[:rails_settings_defaults] = value
  end

  #get or set a variable with the variable as the called method
  def self.method_missing(method, *args)
    if self.respond_to?(method)
      super
    else
      method_name = method.to_s
    
      #set a value for a variable
      if method_name =~ /=$/
        var_name = method_name.gsub('=', '')
        value = args.first
        self[var_name] = value
    
      #retrieve a value
      else
        self[method_name]
      
      end
    end
  end
  
  #destroy the specified settings record
  def self.destroy(var_name)
    var_name = var_name.to_s
    begin
      target(var_name).destroy
      true
    rescue NoMethodError
      raise SettingNotFound, "Setting variable \"#{var_name}\" not found"
    end
  end

  #retrieve all settings as a hash (optionally starting with a given namespace)
  def self.retrieve_all(starting_with=nil)
    scope = target_scoped
    scope = scope.where("var LIKE '#{starting_with}%'") if starting_with
    vars = scope.select('var, value')

    result = {}
    vars.each do |record|
      result[record.var] = record.value
    end
    selected_defaults = defaults.select{ |k, v| k =~ /^#{starting_with}/ }
    selected_defaults = Hash[selected_defaults] if selected_defaults.is_a?(Array)
    selected_defaults.merge(result).with_indifferent_access
  end
  
  #get a setting value by [] notation
  def self.[](var_name)
    if var = target(var_name)
      var.value
    else
      if target_id.nil?
        defaults[var_name.to_s]
      else
        target_type.constantize.settings[var_name.to_s]
      end
    end
  end
  
  #set a setting value by [] notation
  def self.[]=(var_name, value)
    record = target_scoped.find_or_initialize_by(var: var_name.to_s)
    record.value = value
    record.save!
    value
  end
  
  def self.merge!(var_name, hash_value)
    raise ArgumentError unless hash_value.is_a?(Hash)
    
    old_value = self[var_name] || {}
    raise TypeError, "Existing value is not a hash, can't merge!" unless old_value.is_a?(Hash)
    
    new_value = old_value.merge(hash_value)
    self[var_name] = new_value if new_value != old_value
    
    new_value
  end

  def self.target(var_name)
    target_scoped.find_by_var(var_name.to_s)
  end
  
  #get the value field, YAML decoded
  def value
    YAML::load(self[:value])
  end
  
  #set the value field, YAML encoded
  def value=(new_value)
    self[:value] = new_value.to_yaml
  end
  
  def self.target_scoped
    Settings.where(target_type: target_type, target_id: target_id)
  end
  
  #Deprecated!
  def self.reload # :nodoc:
    self
  end
  
  def self.target_id
    nil
  end

  def self.target_type
    nil
  end
end
