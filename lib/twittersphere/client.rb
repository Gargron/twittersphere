require 'twitter'

module Twittersphere
  class Client
    attr_reader :user_store, :seed_user

    # Fetch seed user, load user store
    def initialize(seed_user_name, max_depth, max_friends)
      @user_store  = load_store
      @seed_user   = client.user(seed_user_name) unless seed_user_name.nil?
      @max_depth   = max_depth
      @max_friends = max_friends
    end

    # Make sure seed user is in the store, commence recursive network fetching algorithm
    def run
      unless @user_store.has_key? @seed_user.id
        @user_store[@seed_user.id] = UserWrapper.new(@seed_user)
      end

      get_friend_network(@seed_user.id)
    end

    protected

    # Breadth-first graph search, sorta, I think
    def get_friend_network(centre, current_depth = 0, closed_list = [])
      return closed_list if current_depth == @max_depth
      return closed_list if closed_list.include? centre

      closed_list << centre
      user = nil

      # Get current user info
      unless @user_store.has_key? centre
        user = fetch_user(centre)

        return closed_list if user == false

        @user_store[centre] = user
      else
        user = @user_store[centre]
      end

      puts "Looking at #{user.name} (depth: #{current_depth})"

      # Get friend IDs of the user
      if user.friends.nil?
        return closed_list unless fetch_friends(user)
      end

      # Fetch the friends straight away in a batch
      fetch_user_batched(user.friends)

      # Sync to disk so that if we have to interrupt at some point,
      # we don't lose previous progress
      save_store

      # Recursion
      if current_depth + 1 < @max_depth
        user.friends.each do |follower_id|
          closed_list = get_friend_network(follower_id, current_depth + 1, closed_list)
        end
      end

      return closed_list
    end

    # Fetch a single user, retry if rate limited
    def fetch_user(id)
      puts "Hitting the API (user for #{id})"

      begin
        user = client.user(id)
      rescue Twitter::Error::NotFound => error
        return false
      rescue Twitter::Error::TooManyRequests => error
        puts "Hit the rate limit while fetching user, waiting for #{error.rate_limit.reset_in} seconds"
        sleep error.rate_limit.reset_in + 1
        retry
      end

      UserWrapper.new(user)
    end

    # Fetch friend IDs, retry if rate limited
    def fetch_friends(user)
      puts "Hitting the API (friend_ids for #{user.name})"

      begin
        # Saves only a random sample of 200 friend IDs max
        # This saves space and runtime, though this might be the wrong way to do it
        user.friends = client.friend_ids(user.user_id).to_a.sample(@max_friends)
      rescue Twitter::Error::Unauthorized => error
        puts "Private, moving on"
        return false
      rescue Twitter::Error::TooManyRequests => error
        puts "Hit the rate limit while fetching friends, waiting for #{error.rate_limit.reset_in} seconds"
        sleep error.rate_limit.reset_in + 1
        retry
      end

      return true
    end

    # Fetch a bunch of user profiles at the same time, retry if rate limited
    def fetch_user_batched(ids)
      fetch_ids = ids.reject { |id| @user_store.has_key? id }
      puts "Hitting the API (users for #{fetch_ids.inspect})"

      fetch_ids.each_slice(100) do |*ids_batch|
        begin
          client.users(ids_batch).each do |user|
            @user_store[user.id] = UserWrapper.new(user)
          end
        rescue Twitter::Error::NotFound => error
          # Nothing
        rescue Twitter::Error::TooManyRequests => error
          puts "Hit the rate limit while fetching users, waiting for #{error.rate_limit.reset_in} seconds"
          sleep error.rate_limit.reset_in + 1
          retry
        end
      end
    end

    private

    # Return Twitter client instance
    def client
      @client ||= Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TW_CONSUMER_KEY']
        config.consumer_secret     = ENV['TW_CONSUMER_SECRET']
        config.access_token        = ENV['TW_ACCESS_TOKEN']
        config.access_token_secret = ENV['TW_ACCESS_TOKEN_SECRET']
      end
    end

    # Load user store from a marshaled dump on the disk, or initialize an empty hash
    def load_store
      store = nil

      begin
        store = Marshal.load(File.read('./dump.dat'))
      rescue Errno::ENOENT
      end

      if store.nil?
        store = Hash.new
      end

      store
    end

    # Marshal dump the user store to the disk
    def save_store
      File.open('./dump.dat', 'w') { |f| f.print Marshal.dump(@user_store) }
    end
  end
end
