require 'firebase'

class FirebaseStore

	def initialize db_uri=''
		@firebase = Firebase::Client.new db_uri
	end

	def get where='', pretty=true
		if pretty then return @firebase.get where, {"print" => "pretty"} end
		@firebase.get where
	end

	def delete where='', pretty=true
		if pretty then return @firebase.delete where, {"print" => "pretty"} end
		@firebase.delete where
	end

	def push where='', what={}, pretty=true
		if pretty then return @firebase.push where, what, {"print" => "pretty"} end
		@firebase.push where, what
	end

	def set where='', what={}, pretty=true
		if pretty then return @firebase.set where, what, {"print" => "pretty"} end
		@firebase.set where, what
	end
end
