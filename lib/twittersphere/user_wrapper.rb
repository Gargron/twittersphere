module Twittersphere
  class UserWrapper
    attr_accessor :user_id, :name, :weight, :friends

    # Only saves the barest minimum details we might need to save space
    def initialize(user, friends = nil)
      @user_id = user.id
      @name    = user.screen_name
      @weight  = user.followers_count
      @friends = friends
    end
  end
end
