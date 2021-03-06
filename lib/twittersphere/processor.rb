module Twittersphere
  class Processor
    def initialize(client)
      @user_store = client.user_store
      @seed_user  = client.seed_user
    end

    # Commence recursive graph building algorithm
    def run
      edges = process_follower_list(@seed_user.id, [], 0, 3)
      edges.uniq
    end

    protected

    # Starting with the seed user, create a list of edges user1 --follows--> user2
    def process_follower_list(id, edges = [], depth = 0, max_depth = 2)
      return edges unless @user_store.has_key? id

      user = @user_store[id]

      # Skip edges from users who don't follow anyone or have less than 10 followers themselves
      return edges if user.friends.nil? || user.weight < 10

      user.friends.each do |follower_id|
        next unless @user_store.has_key? follower_id

        following = @user_store[follower_id]

        # Skip edges to users with 10k users and more, we don't need the famous people
        next if following.weight > 9999

        edges << [user, following]

        if depth + 1 < max_depth
          process_follower_list(follower_id, edges, depth + 1, max_depth)
        end
      end

      return edges
    end
  end
end
