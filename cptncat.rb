require 'rubygems' rescue nil
require 'chingu'
include Gosu

module Tiles
  Grass = 0
  Earth = 1
  Growth = 2
  Brick = 3
  Wood = 4
  Leaves = 5
  Grey = 6
  Peach = 7
  Blue = 8
  White = 9
end

#
#                                                 WINDOW CLASS
#   Window Class
#
class Game < Chingu::Window
  attr_reader :map

  def initialize
    super(640, 480, false)
    self.caption = "Cptn. Cat - modified from Cptn. Ruby with Wall Jump"
    @map = Map.new(self, "media/map.txt")
    @cptn = CptnRuby.new(self, 100, 100)
    # Scrolling is stored as the position of the top left corner of the screen.
    @screen_x = @screen_y = 0
    Sound["media/boing1.ogg"] # cache sound by accessing it once
    Sound["media/boing2.ogg"]
    Sound["media/chime2.ogg"]
    Sound["media/meow.ogg"]
    Sound["media/crush.ogg"]
    Sound["media/intro.ogg"].play(0.5) # Intro Music
  end
  def update
    move_x = 0
    move_x -= 7 if button_down? Button::KbLeft
    move_x += 7 if button_down? Button::KbRight
    @cptn.update(move_x)
    @cptn.collect_gems(@map.gems)
    # Scrolling follows player
    @screen_x = [[@cptn.x - 320, 0].max, @map.width * 50 - 640].min
    @screen_y = [[@cptn.y - 240, 0].max, @map.height * 50 - 480].min
  end
  def draw
    @map.draw @screen_x, @screen_y
    @cptn.draw @screen_x, @screen_y
  end
  def button_down(id)
    if id == Button::KbUp then @cptn.try_to_jump end
    if id == Button::KbSpace then @cptn.try_to_jump end
    if id == Button::KbEscape then close end
  end
end


#                                                   PLAYER CLASS
#  Player class
#
class CptnRuby < Chingu::GameObject
  traits :timer
  attr_reader :x, :y

  def initialize(window, x, y)
    @x, @y = x, y
    @dir = :left
    @vy = 0 # Vertical velocity
    @vx = 0 # Horizontally velocity for wall-jumping goodness
    @wall = 0 # Wall climbing or not
    @map = window.map

    # Load all animation frames
    @standing, @walk1, @walk2, @jump, @wall_climb, @blink=
      *Image.load_tiles(window, "media/cpncat.png", 50, 50, false)
    # This always points to the frame that is currently drawn.
    # This is set in update, and used in draw.
    @cur_image = @standing    
    @smoke = [] #Captain Ruby should have an array of particles stored. He creates them
                #However there is possibly a more ideal way of doing this but I'm a Ruby newb. :D
    @window = window
    @boing = true
    @cooling_down = 32
  end

  def draw(screen_x, screen_y)
    # Flip vertically when facing to the left.
    if @dir == :left then
      offs_x = -25
      factor = 1.0
    else
      offs_x = 25
      factor = -1.0
    end
    @cur_image.draw(@x - screen_x + offs_x, @y - screen_y - 49, 0, factor, 1.0)
    
    #draw character's smoke too
    @smoke.each { |s| s.draw(screen_x, screen_y) }
  end
  
  # Could the object be placed at x + offs_x/y + offs_y without being stuck?
  def would_fit(offs_x, offs_y)
    # Check for map collisions
    not @map.solid?(@x + offs_x - 10, @y + offs_y) and
      not @map.solid?(@x + offs_x + 10, @y + offs_y) and
        not @map.solid?(@x + offs_x - 10, @y + offs_y - 45) and
          not @map.solid?(@x + offs_x + 10, @y + offs_y - 45)
  end
  
  def update(move_x)
    if @wall == 0
      @cooling_down = 32
    end
    # Select image depending on action
    if (move_x == 0)
        @cur_image = (milliseconds / 175 % 8 == 0) ? @blink : @standing
    else 
      @cur_image = (milliseconds / 140 % 2 == 0) ? @walk1 : @walk2
#      puts (milliseconds / 175 % 4)
    end
    if (@vy != 0)
      @cur_image = @jump
    else
      if (@vy == 0 && would_fit(0,1))
        @cur_image = @jump
      end
    end
    if @wall != 0
      #if you are wall-climbing, set the image to so
      @cur_image = @wall_climb
      self.crush   # wall-climb sound effect
    end

    # Acceleration/gravity
    # By adding 1 each frame, and (ideally) adding vy to y, the player's
    # jumping curve will be the parabole we want it to be.
    @vy += 1
    # Vertical movement
    #if @vy != 1; puts @vy; end
    if @vy > 0
      @vy.times { if would_fit(0, 1) then @y += 0.75 
        @wall = 0 #The character is jumping, therefore there is no way the character is on a wall.
        else @vy = 0 
        @wall = 0 end } #The character is jumping, therefore there is no way the character is on a wall.
    end
    if @vy < 0 then
      (-@vy).times { if would_fit(0, -1) then @y -= 0.75 else @vy = 0 end }
      @wall = 0 #The character is jumping, therefore there is no way the character is on a wall.
    end
    
    # Directional walking, horizontal movement
    if move_x > 0 then
      @dir = :right
        move_x.times { if would_fit(1, 0) then 
          @x += 1 
          else #If you cannot fit, that means you will most likely be on a wall
            if @vy > 1 then #So if you are not standing still... 
              @vy/=2 #dampen the velocity
              @wall = 1 #We move to the right.
            i = 0
              while i < 4 #Create dust particles
                  i += 1
                  @smoke.push(DustParticle.new(@window, (@x-20) + ( @wall*5) + (@wall * rand(10)), @y-10 , rand(50)))
              end
            end
        end }
    end
    if move_x < 0 then
      @dir = :left
        (-move_x).times { if would_fit(-1, 0) then 
          @x -= 1 
          else #If you cannot fit, that means you will most likely be on a wall
            if @vy > 1 then #So if you are not standing still... 
              @vy/=2 #dampen the velocity
              @wall = -1 #We move to the left.
            i = 0
              while i < 4 #Create dust particles
                  i += 1
                  @smoke.push(DustParticle.new(@window, @x + ( @wall*5) + (@wall * rand(10)), @y - 14, rand(50)))
                end
            end
        end }
      end
    
    #Now we have to check the x velocity which is used when wall jumping
    #It's pretty much the same as the y velocity
    if @vx > 0 then
      @vx -= 1
      @vx.times{if would_fit(-2, 0) then @x -= 2 end}
    end
    if @vx < 0 then
      @vx += 1
      (-@vx).times{if would_fit(2, 0) then @x += 2 end}
    end

    @smoke.each { |s| s.update }        #update the smoke
    @smoke.reject! do |s|          #manage the smoke particles
      s.remove?
    end
  end
  
  def try_to_jump
    if not would_fit(0, 1) then
      @vy = -23
      @wall = 0 #Not climing walls anymore you monkey
      if @boing == true
        Sound["media/boing1.ogg"].play(0.4)
        @boing = false
      else
        Sound["media/boing2.ogg"].play(0.4)
        @boing = true
      end
    end    
    if @wall != 0
        @vy = -23 #On a wall and jumping? Walljump!
        @vx = 12 * @wall #Set the x velocity according to the direction we face from the wall
        @wall = 0
      if @boing == true
        Sound["media/boing1.ogg"].play(0.4)
        @boing = false
      else
        Sound["media/boing2.ogg"].play(0.4)
        @boing = true
      end
    end
  end
  
  def collect_gems(gems)      # Same as in the gosu tutorial game.
    gems.reject! do |c|
      (c.x - @x).abs < 50 and (c.y - @y).abs < 50 and self.chime#Sound["media/chime.ogg"].play(0.8)
    end
  end

  def chime
#    Sound["media/chime2.ogg"].play(0.5)
    if rand(6) == 1
      Sound["media/meow.ogg"].play(1.0)
      Sound["media/chime2.ogg"].play(0.3)
    else
      Sound["media/chime2.ogg"].play(0.5)
    end
  end

  def crush     # wall-climb sound effect
    if @cooling_down >= 26
      Sound["media/crush.ogg"].play(0.5)
      @cooling_down = 0
    else
      @cooling_down += 1
    end
  end
end

#
# Map Class                                           MAP CLASS
# holds and draws tiles and gems.
#
class Map < Chingu::GameObject
  attr_reader :width, :height, :gems
  
  def initialize(window, filename)
    # Load 60x60 tiles, 5px overlap in all four directions.
    @tileset = Image.load_tiles(window, "media/tileset.png", 60, 55, true)
    @sky = Image.new(window, "media/sky.png", true)

    gem_img = Image.new(window, "media/gem.png", false)
    @gems = []

    lines = File.readlines(filename).map { |line| line.chop }
    @height = lines.size
    @width = lines[0].size
    @tiles = Array.new(@width) do |x|
      Array.new(@height) do |y|
        case lines[y][x, 1]
        when '"'
          Tiles::Grass
        when '#'
          Tiles::Earth
        when '-'
          Tiles::Growth
        when 'B'
          Tiles::Brick
        when 'w'
          Tiles::Wood
        when 'l'
          Tiles::Leaves
        when 'g'
          Tiles::Grey
        when 'p'
          Tiles::Peach
        when 'b'
          Tiles::Blue
        when 'W'
          Tiles::White
        when 'x'
          @gems.push(CollectibleGem.new(gem_img, x * 50 + 25, y * 50 + 25))
          nil
        else
          nil
        end
      end
    end
  end
  
  def draw(screen_x, screen_y)
    # Sigh, stars!
    @sky.draw(0, 0, 0)

    # Very primitive drawing function:
    # Draws all the tiles, some off-screen, some on-screen.
    @height.times do |y|
      @width.times do |x|
        tile = @tiles[x][y]
        if tile
          # Draw the tile with an offset (tile images have some overlap)
          # Scrolling is implemented here just as in the game objects.
          @tileset[tile].draw(x * 50 - screen_x - 5, y * 50 - screen_y - 5, 0)
        end
      end
    end
    @gems.each { |c| c.draw(screen_x, screen_y) }
  end
  
  def solid?(x, y)     # Solid at a given pixel position?
    y < 0 || @tiles[x / 50][y / 50]
  end
end

#
#                                                    GEM CLASS
#  Gem Class
#
class CollectibleGem < Chingu::GameObject
  attr_reader :x, :y

  def initialize(image, x, y)
    @image = image
    @x, @y = x, y
    @initTime = Gosu::milliseconds #the the milliseconds when created
    @delay = (rand 100)+1 #add a delay to the time so they move differently
  end
  
  #thisTime is the gems own independant time so they all move differently.
  #quite handy in independant animations like on-the-spot explosions.
  def thisTime
    Gosu::milliseconds - @initTime/@delay
  end
  
  def draw(screen_x, screen_y)
    # Draw, slowly rotating
    @image.draw_rot(@x - screen_x, @y - screen_y, 0,
      25 * Math.sin(thisTime / 133.7))
  end
end

#
#                                                  DUST PARTICLE CLASS
# DustParticle Class
# draws "smoke" at the given position with 
# a given lifespan. The lifespan shares a value with alpha
# so as the life decreases, so does the visibility.
class DustParticle < Chingu::GameObject
  attr_reader :x, :y
  
  def initialize(window, x, y, life)
    @x = x
    @y = y
    @graphic = Image.new(window, "media/dust.png", false)
    @lifespan = life
    @color = Gosu::Color.new(0xff000000)
    #make the color "brownish" corresponding to the tile
    @color.red = 175
    @color.green = 124
    @color.blue = 60
    amount = 0
    if @lifespan > 150 then
      amount = 255
    else
      amount = @lifespan - 38
    end    
    @color.alpha = amount
  end
  
  def draw(screen_x, screen_y)
    if ( @lifespan > 1 ) then
    @graphic.draw(@x - screen_x, @y - screen_y, 0, 1,1, @color)
      end
  end
      
  def update
    @lifespan -=1    
    if @color.alpha > 0 then
      @color.alpha = @lifespan
    else
     @color.alpha = 0
    end
  end
  
  def remove?
    if @lifespan < 1 then
      true
    else
      false
    end
  end
end


Game.new.show
