class SpecialCollection < ActiveRecord::Base

  has_many :lists

  def self.create_all
    self.create(:name => 'Focus')
    self.create(:name => 'Inbox')
    self.create(:name => 'Task')
    self.create(:name => 'Watch')
  end

  def self.focus # This is a community's focus collection
    cached_find(:name, 'Focus')
  end

  def self.inbox
    cached_find(:name, 'Inbox')
  end

  def self.task
    cached_find(:name, 'Task')
  end

  def self.watch
    cached_find(:name, 'Watch')
  end

end
