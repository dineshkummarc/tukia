class Gender < ActiveRecord::Base
  belongs_to :globalize_language
  translates :name
  has_many :terms
  validates_presence_of :name
  validates_presence_of :code
end
