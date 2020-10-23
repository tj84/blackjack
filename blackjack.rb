# load libs and required files
require 'colorize' # to add colour to terminal output

# game constants
BLACKJACK = 21
DEALER_STANDS = 17
RESHUFFLE_THRESHOLD = 30
PAYOUT = 1.5 # 3:2
MIN_BET = 2
MAX_BET = 500
DOUBLE_DOWN_TOTALS = [9,10,11]
# create a deck of cards
class Card
  attr_reader :suit, :face

  def initialize(suit, face)
    @suit = suit
    @face = face
  end

  def to_s
     "#{face} of #{suit}"
  end

  def ==(other)
    self.suit == other.suit &&
    self.face == other.face
  end
end

class CardDeck
  SUITS = ['CLUBS', 'SPADES', 'HEARTS', 'DIAMONDS']
  FACES = [2, 3, 4, 5, 6, 7, 8, 9, 10, 'JACK', 'QUEEN', 'KING', 'ACE']

  def initialize(decks = 1)
    @deck = []
    decks.times do
      SUITS.each do |suit|
        FACES.each do |face|
          @deck << Card.new(suit, face)
        end
      end
    end
    @deck.shuffle!
  end

  def size
    @deck.size()
  end

  def to_s
    puts @deck.each {|card| card.to_s}
  end

  def draw
    @deck.pop
  end
end

class Hand
  attr_accessor :hand_value
  attr_accessor :bet
  attr_accessor :insurance_bet
  attr_accessor :cards

  def initialize
    @cards = []
    @hand_value = 0
    @bet = 0
    @insurance_bet = 0
  end

  def print_hand
    cards = ""
    calculate_hand_value
    @cards.each {|card| cards += card.to_s + ", "}
    return cards
  end

  def calculate_hand_value
    @hand_value = 0
    aces = 0
    @cards.each do |card|
      #puts card.face.class
      if card.face.is_a? Integer
        @hand_value += card.face
      else
        if card.face == "ACE"
          aces += 1
          @hand_value += 11
        else
          @hand_value += 10
        end
      end
    end
    while @hand_value > BLACKJACK && aces > 0
      @hand_value -= 10
      aces -= 1
    end
  end
end

class Player
  attr_accessor :hands
  attr_accessor :funds
  attr_accessor :single_card_move

  def initialize
    @hands = []
    @hands << Hand.new
    @funds = 1000
    @player_number = self.class.player_number
    @single_card_move = false
  end

  def self.player_number
    @players ||= 0
    @players += 1
  end

  def to_s
    "Player #{@player_number}".light_yellow
  end

  def print_hand(hand)
    cards = hand.print_hand
    "#{self}'s cards: #{cards}value: #{hand.hand_value}"
  end

  def update_winnings(factor, bet)
    winnings = bet * factor    # need to edit to reflect bet!
    @funds += winnings
  end

  def reset
    @hands.clear
    @hands << Hand.new
    @single_card_move = false
  end
end

class Dealer < Player

  def initialize
    @first_printing = true
    super
  end

  def to_s
    "Dealer".yellow
  end

  def reset
    @first_printing = true
    super
  end

  def print_hand(hand)
    if @first_printing
      @first_printing = false
      hand.calculate_hand_value
      puts "#{self}'s visible card is: #{hand.cards[0].to_s}"
    else
      super
    end
  end
end

class Blackjack
  attr_accessor :players
  attr_accessor :dealer
  attr_accessor :everyone
  attr_accessor :deck
  attr_reader :all_players

  def initialize
    # create a deck of cards
    @deck = CardDeck.new(3)
    @everyone = []
    @players = []
    setup_players
    # copy of all players for playing multiple rounds
    # (updates as players run out of funds or stop playing)
    @all_players = players.clone
    @dealer = Dealer.new
    @everyone << @dealer
  end

  def setup_players
    puts "How many players are playing?"
    num_players = gets.chomp.to_i
    num_players.times do
      player = Player.new
      everyone << player
      players << player
    end
  end

  def setup_round
    # get a copy of the players in the round
    @players = @all_players.clone
    @dealer.reset
  end

  def reshuffle
    # check how many cards are left in the deck if less than threshold need to
    # add all discarded cards back and reshuffle - same as creating new deck
    if @deck.size < RESHUFFLE_THRESHOLD
      puts "Less than #{RESHUFFLE_THRESHOLD} cards left - reshuffling!"
      @deck = CardDeck.new(3)
    end
  end

  def ask_for_bets
    players.each do |player|
      loop do
        puts "How much would you like to bet #{player}? (Min £2 max £500)"
        user_input = gets.chomp.to_i
        if user_input >= 2 && user_input <= 500 && user_input <= player.funds
          player.hands[0].bet = user_input
          player.funds -= user_input
          break
        end
        puts "Invalid bet or insufficent funds! (funds: #{player.funds})".light_red
      end
    end
  end

  def inital_deal
    2.times do
      @everyone.each do |person|
        person.hands[0].cards << @deck.draw
      end
    end
    #dealer.hands[0].cards[0] = Card.new("b", "ACE")
    #dealer.hands[0].cards[1] = Card.new("c", 10)
  end

  def players_left?
    @all_players.size > 0
  end

  def print_hands
    @everyone.each do |person|
      puts person.print_hand(person.hands[0])
    end
  end

  def insurance
    # if the dealers first (visible) card is an ace ask if the players want to
    # place an insurance bet incase the dealer has a natural blackjack. This bet
    # is up to half the origianl bet
    if dealer.hands[0].cards[0].face == "ACE"
      players.each do |player|
        puts "#{player} would you like to place an insurance bet? Yes (y) or No (n)"
        players_response = gets.chomp
        case players_response
        when "y"
          get_insurance_bet(player)
        else
          puts "You have decided not to place an insurance bet"
        end
      end
    end
  end

  def naturals
    dealer_blackjack = dealer.hands[0].hand_value == BLACKJACK ? true:false
    dealer_natural_message if dealer_blackjack
    players.select! do |player|
      player_blackjack = player.hands[0].hand_value == BLACKJACK ? true:false
      settle_insurance_bets(player, dealer_blackjack)
      nautrals_outcome(player_blackjack, dealer_blackjack, player)
    end
  end

  def players_play
    players.each do |player|
      # ask if the player wants to split pairs if the first two cards are the same
      # and player has sufficent funds
      if player.hands[0].cards[0] == player.hands[0].cards[1] &&
        player.funds >= player.hands[0].bet
        ask_and_split_pairs(player)
      end
      # ask if player wants to double down if the two cards total 9,10 or 11 and
      # they haven't already split their hand and player has sufficent funds
      if DOUBLE_DOWN_TOTALS.include?(player.hands[0].hand_value) &&
        player.hands.size < 2 && player.funds >= player.hands[0].bet
        ask_and_double_down(player)
      end
      # the player can now chose to draw more cards or stand for each of
      # the hands - unless they have split aces or doubled down (one get 1 card)
      if !player.single_card_move
        players_moves(player)
      end
    end
  end

  def dealer_plays
    while dealer.hands[0].hand_value < DEALER_STANDS
      dealer.hands[0].cards << deck.draw
      dealer.hands[0].calculate_hand_value
    end
    puts dealer.print_hand(dealer.hands[0])
  end

  def resolve_hands
    players.each do |player|
      player.hands.each do |hand|
        hand.calculate_hand_value
        if hand.hand_value > BLACKJACK
          puts "#{player} lost! (#{hand.hand_value})".light_red
        elsif dealer.hands[0].hand_value <= BLACKJACK
          non_bust_dealer_outcomes(player, hand, dealer)
        else
          puts "#{player} (#{hand.hand_value}) wins against a bust dealer!"\
          "(#{dealer.hands[0].hand_value})".light_green
          # return bet and pay out bet
          player.update_winnings(2, hand.bet)
        end
      end
    end
  end

  def print_players_funds
    @all_players.each do |player|
       puts "#{player}'s funds is: £#{player.funds}"
    end
  end

  def another_round
    # ask each of the players if they want to play again, only if they have sufficent funds
    @all_players.select! do |player|
      if player.funds >= MIN_BET
        puts "#{player} would you like to play another round? Yes (y) or No (n)"
        player_choice = gets.chomp
        case player_choice
        when "y"
          # reset players hand to start new round
          player.reset
          true # select
        when "n"
          @everyone.delete(player)
          false # don't select
        end
      else
        puts "#{player} doesn't have sufficent funds so can't take part in the next round"
        @everyone.delete(player)
        false
      end
    end
  end

  private

  def dealer_natural_message
    puts "#{dealer} has a natural blackjack".light_green
    puts dealer.print_hand(dealer.hands[0])
  end

  def nautrals_outcome(player_blackjack, dealer_blackjack, player)
    if dealer_blackjack && !player_blackjack
      puts "#{player} lost against a natural blackjack".light_red
      false # remove player for the list of players
    elsif dealer_blackjack && player_blackjack
      puts "#{player} also has a natural blackjack and draw".light_green
      player.update_winnings(1, player.hands[0].bet) # return bet
      false
    elsif !dealer_blackjack && player_blackjack
      puts "#{player} has a natural blackjack and wins!".light_green
      player.update_winnings(2.5, player.hands[0].bet)
      false
    else
      true # player to keep on playing (no natural blackjacks)
    end
  end

  def get_insurance_bet(player)
    half_bet = player.hands[0].bet/2
    loop do
      puts "#{player} how much would you like your insurance bet to be -
      up to £#{half_bet}"
      user_input = gets.chomp.to_i
      if user_input > 0 && user_input <= half_bet && user_input <= player.funds
        player.hands[0].insurance_bet = user_input
        player.funds -= player.hands[0].insurance_bet
        break
      end
      puts "Invalid insurance bet".light_red
    end
  end

  def ask_and_split_pairs(player)
    puts "#{player} would you like to split your pairs?"
    player_response = gets.chomp
    case player_response
    when "y"
      player.hands << Hand.new
      player.hands[1].cards << player.hands[0].cards.pop
      player.hands[1].bet = player.hands[0].bet
      player.hands.each {|hand| hand.calculate_hand_value}
      split_aces(player) if player.hands[0].cards[0].face == "ACE"
    else
      puts "#{player} is not splitting the pairs"
    end
  end

  def split_aces(player)
    # if player has a pair of aces he only gets one extra card per split hand
    # and his turns are over
    player.hands[0].cards << deck.draw
    player.hands[1].cards << deck.draw
    player.hands.each {|hand| hand.calculate_hand_value}
    player.single_card_move = true
  end

  def ask_and_double_down(player)
    puts "#{player} you are able to double down, would you like to? Yes (y) or No (n)"
    player_response = gets.chomp
    case player_response
    when "y"
      puts "#{player} is doubling down!"
      player.funds -= player.hands[0].bet # take the extra bet from funds
      player.hands[0].bet *= 2 # update the inital bet to be double
      player.hands[0].cards << deck.draw # player only gets one card (face down)
      player.single_card_move = true # can't draw any more cards
    else
      puts "#{player} is not doubling down"
    end
  end

  def players_moves(player)
    player.hands.each do |hand|
      player_move = ""
      while player_move != "s" and hand.hand_value <= BLACKJACK
        puts "Your turn #{player}, your current hand value is: #{hand.hand_value}"
        puts "#{player} this is split hand number: #{player.hands.index(hand) + 1}" unless player.hands.size < 2
        puts "Please pick: (h) Hit or (s) Stand"
        player_move = gets.chomp
        case player_move
        when "h"
          puts "#{player} hits!"
          hand.cards << deck.draw
          puts player.print_hand(hand)
        when "s"
          puts "#{player} stands!".light_cyan
        else
          puts "Not a valid move!".red
          puts "Please choose (h) Hit or (s) Stand"
        end
      end
      if hand.hand_value > BLACKJACK
        puts "#{player} lost!".light_red
      end
    end
  end

  def non_bust_dealer_outcomes(player, hand, dealer)
    if hand.hand_value > dealer.hands[0].hand_value
      puts "#{player} (#{hand.hand_value}) wins against the dealer"\
      " (#{dealer.hands[0].hand_value})".light_green
      # return bet and pay out bet
      player.update_winnings(2, hand.bet)
    elsif hand.hand_value == dealer.hands[0].hand_value
      puts "#{player} (#{hand.hand_value}) has drawn with the dealer!"\
      " (#{dealer.hands[0].hand_value})".green
      # return bet
      player.update_winnings(1, hand.bet)
    else
      puts "Dealer (#{dealer.hands[0].hand_value}) has won against"\
      " #{player} (#{hand.hand_value})!".light_red
    end
  end

  def settle_insurance_bets(player, dealer_blackjack)
    if player.hands[0].insurance_bet != 0 &&
      dealer_blackjack
      puts "Your insurance bet paid off!".light_green
      player.update_winnings(3, player.hands[0].insurance_bet)
    elsif player.hands[0].insurance_bet != 0 &&
      !dealer_blackjack
      puts "Your insurance bet did not pay off".light_red
    end
  end
end

game = Blackjack.new
while game.players_left?

  game.setup_round

  game.ask_for_bets

  game.reshuffle

  game.inital_deal

  game.print_hands

  game.insurance

  game.naturals

  game.players_play

  game.dealer_plays

  game.resolve_hands

  game.print_players_funds

  game.another_round
end
