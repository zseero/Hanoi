require 'socket'

$count = 0
$mac_addrs = []

for fileName in Dir['./*']
	if fileName.split('.')[-1] == 'dat'
		i = fileName[2].to_i
		$count = i + 1 if i >= $count
		file = File.new(fileName, 'r')
		$mac_addrs << file.gets.chomp
		file.close
	end
end

def connect(client)
	data = ''
	while s = client.gets
		s.chomp!
		client.puts
		data += (s + "\n")
	end
	client.close

	oldCount = $count
	$count += 1
	split = data.split("\n")
	if !$mac_addrs.include?(split[0])
		$mac_addrs << split[0]
		puts "Data #{oldCount} collected"
		file = File.open(oldCount.to_s + data.split("\n")[4].split(' : ')[0] + '.dat', 'w')
		puts data
		file.puts(data)
		file.close
	else
		puts "Computer attempted a second connection"
	end
end

def getUsers(server)
	while true
		client = server.accept
		puts 'Connected'
		connect(client)
	end
end

def command(s)
	exits = ['q', 'exit', 'quit']
	exit if exits.include?(s)
	puts $count if s == 'count'
end

Thread.new {while true; command(gets.chomp); end}

server = TCPServer.open('modcraft.me', 27513)
puts 'Starting the server!'
getUsers(server)