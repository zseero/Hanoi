module Index
	MacAddr, Scores, Avg, LearnMode, Answers = *0...5
end

module Question
	Name, Grade, HaveYouPlayed, HowMuchEffort, HowDoYouLearn = *0...5
end

module Learning
	Practice, Reading, Seeing, Demonstration, Hearing = *0...5
	Methods = ['practice', 'reading', 'seeing', 'demonstration', 'hearing']
end

$LogFile = File.open('Analysis.log', 'w')

def log(s)
	if $debug
		$LogFile.puts s
		puts s
	end
end

def getData
	data = []
	for filePath in Dir['./*']
		next if filePath[-4..-1] != '.dat'
		file = File.open(filePath)
		playerData = []
		i = 0
		while s = file.gets
			s.chomp!
			s = s.split(' : ') if i == Index::Answers
			playerData << s
			i += 1
		end
		data << playerData
	end
	data
end

def getTotalAvg(data)
	totalAvg = 0; data.each {|playerData| totalAvg += playerData[Index::Avg].to_f}
	totalAvg /= data.length.to_f
	totalAvg = totalAvg.round(2)
end

def toPercent(num)
	(num * 100).round.to_s + '%'
end

class String
	def super_to_f
		s = dup
		i = 0.0
		while s.length > 0 && i == 0
			i = s.to_f
			s = s[1..-1]
		end
		if i == 0 && self != 'none'
			nums = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']
			for index in 0...(nums.length)
				i = index if include?(nums[index])
			end
		end
		i += 0.5 if include?('half')
		i
	end

	def super_to_i
		super_to_f.to_i
	end

	def to_b
		bool = false
		bool = true if downcase == 'true'
		bool
	end
end

def interpretGrade(data)
	int = 20
	log '=' * int + ' Grades ' + '=' * int
	for playerData in data
		s = playerData[Index::Answers][Question::Grade].downcase
		grade = s.super_to_i
		log "Guessed #{grade.to_s} from \"#{s}\""
		playerData[Index::Answers][Question::Grade] = grade.to_s
	end
end

def interpretEffort(data)
	int = 20
	log '=' * int + ' Effort ' + '=' * int
	for playerData in data
		s = playerData[Index::Answers][Question::HowMuchEffort].downcase
		effort = s.super_to_f
		log "Guessed #{effort.to_s} from \"#{s}\""
		playerData[Index::Answers][Question::HowMuchEffort] = effort.to_s
	end
end

def interpretHasPlayed(data)
	int = 20
	log'=' * int + ' Has Played ' + '=' * int
	for playerData in data
		s = playerData[Index::Answers][Question::HaveYouPlayed].downcase
		bool = true
		noPhrases = ['no', 'nope', 'never', 'n\'t', 'nt', 'not', 'false']
		for no in noPhrases
			bool = false if s.include?(no)
		end
		log "Guessed #{bool.to_s.upcase} from \"#{s}\""
		playerData[Index::Answers][Question::HaveYouPlayed] = bool.to_s
	end
end

def interpretHowDoYouLearn(data)
	int = 20
	log '=' * int + ' How do you Learn ' + '=' * int
	for playerData in data
		s = playerData[Index::Answers][Question::HowDoYouLearn].downcase
		waysYouLearn = []
		keyWordHash = {
			Learning::Practice => ['model', 'hands', 'pratice', 'myself', 'on my own', 'trying', 'experience'],
			Learning::Reading => ['read', 'book', 'text'],
			Learning::Seeing => ['picture', 'diagram', 'see', 'visual'],
			Learning::Demonstration => ['demon', 'watch', 'example'],
			Learning::Hearing => ['audio', 'ear', 'listen', 'lecture', 'expla'],
		}
		keyWordHash.each do |key, value|
			for keyWord in value
				if s.include?(' ' + keyWord)
					waysYouLearn << key
					break
				end
			end
		end
		newAry = []; waysYouLearn.each {|way| newAry << Learning::Methods[way]}
		log "Guessed #{newAry.join(', ').upcase} from \"#{s}\""
		playerData[Index::Answers][Question::HowDoYouLearn] = waysYouLearn.join(' : ')
	end
end

def parseNumData(data)
	int = 20
	log '=' * int + ' Number Parsing ' + '=' * int
	log 'Parsing computer made numbers... (shouldn\'t be a problem...)'
	newData = []
	for playerData in data
		newPlayerData = []
		scores = []
		playerData[Index::Scores].split(' : ').each {|score| scores << score.to_i}
		newPlayerData[Index::Scores] = scores
		newPlayerData[Index::Avg] = playerData[Index::Avg].to_i
		newPlayerData[Index::LearnMode] = playerData[Index::LearnMode].to_i
		newAnswers = []
			answers = playerData[Index::Answers]
			newAnswers[Question::Name] = answers[Question::Name]
			newAnswers[Question::Grade] = answers[Question::Grade].to_i
			newAnswers[Question::HaveYouPlayed] = answers[Question::HaveYouPlayed].to_b
			newAnswers[Question::HowMuchEffort] = answers[Question::HowMuchEffort].to_f
			newMethods = []
			answers[Question::HowDoYouLearn].split(' : ').each {|method| newMethods << method.to_i}
			newAnswers[Question::HowDoYouLearn] = newMethods
		newPlayerData[Index::Answers] = newAnswers
		newData << newPlayerData
	end
	log 'Complete'
	newData
end

def collectValidData(data)
	int = 20
	log '=' * int + ' Validizing ' + '=' * int
	log 'Collecting valid data based on interpretations...'
	validData = []
	for playerData in data
		bool = true
		answers = playerData[Index::Answers]
		bool = false if playerData[Index::Scores].include?(0)
		bool = false if answers[Question::Grade] == 0
		bool = false if answers[Question::HaveYouPlayed]
		bool = false if answers[Question::HowMuchEffort] < 4
		validData << playerData if bool
	end
	log 'Data collected'
	percent = validData.length.to_f / data.length.to_f
	log "Only #{validData.length}/#{data.length}, or #{(percent * 100).to_i}% was valid"
end

def getPrefferedMethodOfLearningScores(data)
	int = 20
	log '=' * int + ' Perffered Learning ' + '=' * int
	scores = Hash.new(0)
	for playerData in data
		playerData[Index::Answers][Question::HowDoYouLearn].each {|method| scores[method] += 1}
	end
end

def getLearningModeScores(data)
	int = 20
	log '=' * int + ' Data Analysis ' + '=' * int
	scores = Hash.new(0)
	for playerData in data
		scores[playerData[Index::LearnMode]] += playerData[Index::Avg]
	end
end

$debug = true
data = getData
log toPercent(getTotalAvg(data))
interpretGrade(data)
interpretEffort(data)
interpretHasPlayed(data)
interpretHowDoYouLearn(data)
data = parseNumData(data)
data = collectValidData(data)

perfferedMethodScores = getPrefferedMethodOfLearningScores(data)
perfferedMethodScores.each {|key, value| log Learning::Methods[key].upcase + ' : ' + value.to_s}

learningModeScores = getLearningModeScores(data)
learningModeScores.each {|key, value| log Learning::Methods[key].upcase + ' : ' + value.to_s}