#ocra --chdir-first HanoiTest.rb lib/*

require 'gosu'
require 'macaddr'

$colors = [
  0xffff0000,#red
  0xffff8800,#orange
  0xffffee00,#yellow
  0xff00ff00,#green
  0xff00ffff,#aqua
  0xff0000ff,#blue
  0xffff00ff,#purple
]

module Layers
	Background, Diagram, Pole, Disk, Text = *0...5
end

module Stage
	Practice, Reading, Seeing, Demonstration, Hearing, Survey, Testing = *0...7
	Learning = [Practice, Reading, Seeing, Demonstration, Hearing]
end

class Array
	def rand
		at(Random.rand(0...length))
	end
end

class Window < Gosu::Window
	attr_reader :dragX, :dragY
	def initialize(main)
		@main = main
		super(Gosu::screen_width, Gosu::screen_height, true)
		@bg = Quad.new(self, Coord.new(0, 0), Coord.new(width, height))
		@bgColor = 0xffffffff
		changeStage(Stage::Learning[0])
	end
	def changeStage(stage)
		@stage = stage
		stageInit
	end
	def basicFontInit
		@fontSize = Coord.new(1, 32)
		@fontSpacing = Coord.new(20, 20)
		@lineSpacing = 20
		@font = Gosu::Font.new(self, Gosu::default_font_name, @fontSize.y)
	end
	def ask
		@askText = ''
	end
	def stageInit
		@continue = false
		@lines = nil
		if @stage == Stage::Survey
			basicFontInit
			@questions = []
			@answers = []
			for fileName in Dir['lib/survey/*']
				shortName = 'survey/' + fileName.split('/')[2]
				@questions << getLinesFromFile(shortName)
			end
			@questionsI = 0
			@lines = @questions[@questionsI]
			ask
		end
		if @stage == Stage::Practice
			@teachingMethod = 'practice'
			basicFontInit
			@lines = getLinesFromFile('practice.txt')
			newGame(2)
		end
		if @stage == Stage::Reading
			@teachingMethod = 'reading'
			@fontSize = Coord.new(1, 20)
			@fontSpacing = Coord.new(20, 20)
			@lineSpacing = 10
			@font = Gosu::Font.new(self, Gosu::default_font_name, @fontSize.y)
			@lines = getLinesFromFile('reading.txt')
		end
		if @stage == Stage::Seeing
			@teachingMethod = 'diagram'
			@img = Gosu::Image.new(self, 'lib/diagram.png', false)
		end
		if @stage == Stage::Hearing
			@teachingMethod = 'hearing'
			basicFontInit
			@lines = getLinesFromFile('hearing.txt')
			require 'win32/sound'
			Win32::Sound.play("lib/HanoiExplanation.wav", Win32::Sound::ASYNC)
		end
		if @stage == Stage::Demonstration
			@teachingMethod = 'demonstration'
			basicFontInit
			@lines = getLinesFromFile('demonstration.txt')
			@time = 0
			@timeThresh = 100
			@demoIndex = 0
			@demoMoveIndex = 0
			towers = (2..15).to_a
			@demos = []
			for tower in towers
				newGame(tower)
				moves = @game.smove(tower, 2)
				@demos << Plan.new(tower, moves)
			end
			newGame(@demos[@demoIndex].towerHeight)
		end
		if @stage == Stage::Testing
			basicFontInit
			@lines = getLinesFromFile('testing.txt')
			@scores = []
			newGame(3)
		end
	end
	def getLinesFromFile(fileName)
		file = File.open('lib/' + fileName, 'r')
		input = []
		while line = file.gets
			input << line.chomp
		end
		lines = []
		for line in input
			lines << ''
			words = line.split(' ')
			for word in words
				if @font.text_width(lines[-1] + ' ' + word, @fontSize.x) < (width - (@fontSpacing.x * 2))
					addOn = word
					addOn = ' ' + addOn if lines[-1].length > 0
					lines[-1] += addOn
				else
					lines << word
				end
			end
		end
		lines
	end
	def newGame(n)
		@game = Game.new(self, n)
	end
	def demonstrationAdvance
		@demoMoveIndex = 0
		@demoIndex += 1
		if @demoIndex >= @demos.length
			changeStage(Stage::Testing)
		else
			newGame(@demos[@demoIndex].towerHeight)
			moves = (@game.getMin(@game.number))
			@timeThresh = 1000 / moves * 0.7
			min = 5
			if @timeThresh < min
				@timeThresh = min
				@min = 0.1
			end
		end
	end
	def update
		@dragX, @dragY = mouse_x, mouse_y
		if @stage == Stage::Survey
			if @enterButton
				@enterButton = false
				text = @askText
				text = 'none' if text == '' || text == ' '
				@answers << text
				@questionsI += 1
				@lines = @questions[@questionsI]
				if @lines.nil?
					@askText = nil
					submitData
				else
					ask
				end
			end
		end
		if Stage::Learning.include?(@stage)
			if @continue
				Win32::Sound.stop if @stage == Stage::Hearing
				i = Stage::Learning.index(@stage)
				if i >= Stage::Learning.length - 1
					changeStage(Stage::Testing)
				else
					changeStage(Stage::Learning[i + 1])
				end
			end
		end
		if @stage == Stage::Demonstration
			@time += 1
			if @time > @timeThresh
				@time = 0
				if @demoMoveIndex >= @demos[@demoIndex].moves.length
					demonstrationAdvance
				else
					move = @demos[@demoIndex].moves[@demoMoveIndex]
					@game.drop(move[1])
					@demoMoveIndex += 1
				end
			end
			demo = @demos[@demoIndex]
			move = demo.moves[@demoMoveIndex] if demo
			if move
				grabbed = @game.grab(move[0])
				if @min
					@timeThresh = 3 * grabbed if grabbed
					@timeThresh = @min if @timeThresh < @min
				end
				third = width.to_f / 3.0
				fromX = ((move[0] + 1) * third - (width.to_f / 6.0)).to_i.to_f
				toX = ((move[1] + 1) * third - (width.to_f / 6.0)).to_i.to_f
				fromY = @game.getAnimationHeight(move[0]).to_f
				toY = @game.getAnimationHeight(move[1]).to_f
				percent = @time.to_f / @timeThresh.to_f
				@dragX = (toX - fromX) * percent + fromX
				xOffSet = ((toX + fromX) / 2) + 0
				yOffSet = [fromY, toY].min - 200
				widthMult = Math.sqrt((toY - yOffSet) / (((toX - xOffSet) ** 2)))
				@dragY = (1 * (((@dragX - xOffSet) * widthMult) ** 2) * 1) + yOffSet
				@dragY = fromY if (fromX - @dragX).abs < (toX - @dragX).abs && @dragY > fromY
				#yOffSet = (toY * (fromA ** 2) - fromY * (toA ** 2)) / ((fromA ** 2) - toA ** 2) - height
				#widthMult = Math.sqrt(toY / (fromA ** 2 - toA ** 2) - fromY / (fromA ** 2 - toA ** 2))
			else
				@timeThresh = 100
			end
		end
		if @stage == Stage::Practice
			if @game.done?
				if @game.number < 3
					newGame(@game.number + 1)
				else
					changeStage(Stage::Testing)
				end
			end
			@game.update
		end
		if @stage == Stage::Testing
			if @game.done? || @continue
				#puts "#{@game.getMin(@game.number)} / #{@game.moves}"
				if !@continue
					@scores << (@game.getMin(@game.number).to_f / @game.moves.to_f).round(2)
				else
					@scores << 0.0
				end
				if @game.number < 6
					newGame(@game.number + 1)
				else
					changeStage(Stage::Survey)
				end
				@continue = false
			end
			@game.update
		end
	end
	def drawLines(lines)
		i = 0
		while i < lines.length
			line = lines[i]
			x = @fontSpacing.x
			y = @fontSpacing.y + (@lineSpacing * i) + (@fontSize.y * i)
			@font.draw(line, x, y, Layers::Text, @fontSize.x, 1, 0xff000000)
			i += 1
		end
	end
	def draw
		@bg.draw(@bgColor, Layers::Background)
		@img.draw(0, 0, Layers::Diagram) if @stage == Stage::Seeing
		@game.draw if @stage == Stage::Practice || @stage == Stage::Testing || @stage == Stage::Demonstration
		if @lines
			l = @lines.dup
			l << @askText if @askText
			drawLines(l)
		end
	end
	def needs_cursor?
		true
	end
	def button_down(id)
		#exit if id == Gosu::KbEscape
		@continue = true if id == Gosu::KbSpace
		@enterButton = true if id == Gosu::KbReturn
		demonstrationAdvance if id == Gosu::KbRight
		char = Gosu::Window.button_id_to_char(id)
		if @askText && char
			if button_down?(Gosu::KbRightShift) || button_down?(Gosu::KbLeftShift)
				char.upcase!
				char = '!' if char == '1'
				char = '?' if char == '/'
				char = '"' if char == '\''
			end
			@askText += char
		end
		if id == Gosu::KbBackspace
			@askText = @askText[0..-2]
		end
	end
	def getData
		avg = 0; @scores.each {|score| avg += score}; avg /= @scores.length
		data = [Mac.addr, @scores.join(' : '), avg, @teachingMethod, @answers.join(' : ')]
	end
	def submitData
		$data = getData
		close
	end
end

class Coord
  attr_accessor :x, :y
  def initialize(x, y)
    @x, @y = x, y
  end
  def dup
    Coord.new(@x, @y)
  end
  def ==(c)
    (@x == c.x && @y == c.y)
  end
  def to_s
    "#{@x}:#{@y}"
  end
end

class Plan
	attr_reader :towerHeight, :moves
	def initialize(towerHeight, moves)
		@towerHeight = towerHeight
		@moves = moves
	end
end

class Quad
  attr_accessor :c1, :c2, :c3, :c4
  def initialize(window, c1, c2, c3 = nil, c4 = nil)
  	@window = window
    @c1, @c2, @c3, @c4 = c1, c2, c3, c4
    if @c3.nil? || @c4.nil?
    	@c3 = @c2.dup
    	@c2 = Coord.new(@c3.x, @c1.y)
    	@c4 = Coord.new(@c1.x, @c3.y)
    end
  end
  def draw(c, z)
    @window.draw_quad(@c1.x, @c1.y, c, @c2.x, @c2.y, c,
                      @c3.x, @c3.y, c, @c4.x, @c4.y, c, z)
  end
end

class Stack
	def initialize()
		@ary = []
	end
	def push(i)
		@ary << i if i
	end
	def pop
		i = get
		@ary.delete_at(-1) if i
		i
	end
	def get(n = -1)
		@ary[n]
	end
	def length
		@ary.length
	end
	def contents
		@ary.dup
	end
	def each
		@ary.each { |i| yield(i) }
	end
	def to_s
		@ary.join(' ')
	end
end

class Game
	attr_reader :moves, :stacks
	def initialize(window, n)
		@window = window
		@img = Gosu::Image.new(@window, 'lib/square.png', false)
		@imgEnd = Gosu::Image.new(@window, 'lib/circle.png', false)
		@pole = Gosu::Image.new(@window, 'lib/pole.png', false)
		@stacks = []
		@n = n
		@moves = 0
		3.times {@stacks << Stack.new}
		i = @n
		@n.times {@stacks[0].push(i); i -= 1}
		@grabbed = nil
	end
	def number; @n; end
	def drop(n)
		if @grabbed
			fdisk = @grabbed[0]
			tdisk = @stacks[n].get
			if fdisk && (tdisk.nil? || fdisk < tdisk)
				@stacks[n].push(@grabbed[0])
				@moves += 1 if @grabbed[1] != n
				@grabbed = nil
			else
				@stacks[@grabbed[1]].push(@grabbed[0])
				@grabbed = nil
			end
		end
	end
	def returnGrab
		if @grabbed
			@stacks[@grabbed[1]].push(@grabbed[0])
			@grabbed = nil
		end
	end
	def grab(n)
		if @grabbed.nil?
			i = @stacks[n].pop
			@grabbed = [i, n] if !i.nil?
		end
		i
	end
	def smove(n, to)
		from = nil
		for i in 0...@stacks.length
		 	from = i if @stacks[i].contents.include?(n)
		end
		aboveMe = n - 1
		moves = []
		if aboveMe > 0
			rows = [0, 1, 2]; rows.delete(from); rows.delete(to)
			moves = smove(aboveMe, rows[0])
		end
		move(from, to)
		moves << [from, to]
		if aboveMe > 0
			moves += smove(aboveMe, to)
		end
		moves
	end
	def move(from, to)
		fdisk = @stacks[from].get
		tdisk = @stacks[to].get
		if fdisk && (tdisk.nil? || fdisk < tdisk)
			@stacks[to].push(@stacks[from].pop)
			@moves += 1
		end
	end
	def done?
		@stacks[2].length == @n
	end
	def getMin(n)
		answer = 1
		(n - 1).times do
			answer = answer * 2 + 1
		end
		answer
	end
	def getAnimationHeight(n)
		@window.height - (@stacks[n].contents.length + 1) * @img.height + (@img.height / 2)
	end
	def update
		i = (@window.mouse_x / (@window.width / 3)).to_i
		i = 2 if i == 3
		if @window.button_down?(Gosu::MsLeft)
			grab(i)
		else
			drop(i)
		end
	end
	def drawDisk(disk, x, y = nil, depth = nil)
		color = $colors[(disk - 1) % $colors.length]
		width = (@window.width / 3)
		part = width / @n
		imgWidth = (@n.to_f / 3.0) * part + disk * (part / 2) - (@imgEnd.width * 2)
		drawX = x - (imgWidth / 2)
		drawY = y
		if !drawY.nil?
			drawY -= (@img.height / 2)
		else
			drawY = @window.height - (@img.height * (depth + 1))
		end
		@img.draw(drawX, drawY, Layers::Disk, imgWidth.to_f / @img.width.to_f, 1, color)
		@imgEnd.draw(drawX - (@imgEnd.width / 2), drawY, Layers::Disk, 1, 1, color)
		@imgEnd.draw(drawX - (@imgEnd.width / 2) + imgWidth, drawY, Layers::Disk, 1, 1, color)
	end
	def draw
		if @grabbed
			drawDisk(@grabbed[0], @window.dragX, @window.dragY)
		end
		for i in 0..2
			stack = @stacks[i]
			width = (@window.width / 3)
			x = width * i
			cx = x + width / 2
			mult = 0.5
			@pole.draw(cx - (@pole.width * mult / 2), @window.height / 2, Layers::Pole, mult, 1)
			for ii in 0...stack.length
				disk = stack.get(ii)
				drawDisk(disk, cx, nil, ii)
			end
		end
	end
end

window = Window.new(self)
window.show

puts "Submitting data..."
Thread.new do
	sleep 5
	puts "Please make sure you are connected to the internet."
	sleep 5
	puts "Connect to an internet hotspot other than the Cary Academy internet."
	sleep 5
	puts "Leave this window open until you are connected to the internet."
	while true
		s = gets.chomp
		exit if s == 'exit'
	end
end

require 'socket'
while true
	begin
		server = TCPSocket.open('modcraft.me', 27513)
	rescue
		puts "Connection attempt failed..."
	end
end
$data.each {|d| server.puts d; server.gets}
server.close
puts "Data submitted."
sleep 5
exit