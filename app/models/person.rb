require 'digest/sha1'

class Person < ActiveRecord::Base
  has_and_belongs_to_many :editorof, :class_name => "Committee", :join_table => "committees_editors"
  has_and_belongs_to_many :convenorof, :class_name => "Committee", :join_table => "committees_convenors"
  has_many :documents
  belongs_to :language, :class_name => "Globalize::Language"
  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)
# again, just a submitted-by field for reference, not policy
  has_many :terms # no dependent-destroy on here because that would just be a pain in the ass (all of the terms
  # a user ever created would get toasted if they were removed)
  has_and_belongs_to_many :nations, :class_name => "Nation"
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :givenname
  validates_presence_of :surname
  #validates_presence_of :password
  validates_presence_of :email
  attr_protected :created_at, :updated_at
  validates_presence_of :time_zone
  
  def find_allowed_committees
    result = []
    if !(@editorof.nil?)
      result = result + self.editorof
    end
    if !(@convenorof.nil?)
      result = result + self.convenorof
    end
    self.nations.each do |n|
      result << n.committee unless result.include?( n.committee )
    end
    return result
  end
  
  def full_name
    self.givenname + " " + self.surname
  end
  
  def update_login_time()
    self.lastlogin_at = Time.now.utc
    self.save!
  end
  
    # Please change the salt to something else, 
  # Every application should use a different one 
  @@salt = 'weenis'
  cattr_accessor :salt

  # Authenticate a user. 
  #
  # Example:
  #   @user = User.authenticate('bob', 'bobpass')
  #
  def self.authenticate(login, pass)
    find_first(["name = ? AND password = ?", login, sha1(pass)])
  end  
  
  protected

  # Apply SHA1 encryption to the supplied password. 
  # We will additionally surround the password with a salt 
  # for additional security. 
  def self.sha1(pass)
    Digest::SHA1.hexdigest("#{salt}--#{pass}--")
  end
  
  validate_on_create :crypt_password
  
  # Before saving the record to database we will crypt the password 
  # using SHA1. 
  # We never store the actual password in the DB.
  def crypt_password
    if password.empty?
      self.errors.add(:password, "can't be blank.")
    end
    if password.length > 50 or password.length < 5
      self.errors.add(:password, "password must be within 5 to 40 characters in length.".t)
      return
    end
    write_attribute "password", self.class.sha1(password)
  end
  
  validate_on_update :crypt_unless_empty
  
  # If the record is updated we will check if the password is empty.
  # If its empty we assume that the user didn't want to change his
  # password and just reset it to the old value.
  def crypt_unless_empty
    user = self.class.find(self.id)
    if self.password == user.password
      # this will occur when a person object is loaded into memory, and then saved, without the password field being touched.
      # do nothing
    elsif password.empty?
      # this is for the case whre the View has set the password to nothing, in the case
      # of the user updating the rest of the Person instance, but wanting to leave the pw unchanged.
      self.password = user.password
    else
      if (password.length > 50) or (password.length < 5)
        self.errors.add(:password, "password must be within 5 to 40 characters in length.".t)
        return
      end 
      write_attribute "password", self.class.sha1(password)
    end        
  end
  
  validates_uniqueness_of :name, :on => :create

  validates_confirmation_of :password
  validates_length_of :name, :within => 3..40
  #validates_length_of :password, :within => 5..40
  
  # AAAAARRRRGGGHHH. if this is left in, it causes the the habtm relationship with Nation
  # fail fantastically on the other side.  I SPENT TWO WHOLE FUCKING WEEKS TRYING TO FIND THIS.
  # " is invalid." is THE most fucking useless error message ever.  I guess the root of the problem
  # is that ActiveRecord disagrees with the idea of validation on a value that doesn't go into the
  # database... some of the time.
  #validates_presence_of :password_confirmation
end
