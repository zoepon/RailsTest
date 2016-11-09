#!/usr/bin/ruby
$KCODE = 'u'
$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/ext/nwsaprfc')
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../ext/nwsaprfc')

require 'sapnwrfc'

$SAP_CONFIG = ENV.has_key?('SAP_YML') ? ENV['SAP_YML'] : 'sap.yml'
$WAIT = 10

require 'test/unit'
require 'test/unit/assertions'

class SAPRegisterTest < Test::Unit::TestCase
	def setup
	  #SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	  if FileTest.exists?($SAP_CONFIG)
  	  SAPNW::Base.config_location = $SAP_CONFIG
		else
  	  SAPNW::Base.config_location = 'test/' + $SAP_CONFIG
		end
	  SAPNW::Base.load_config
    #SAP_LOGGER.warn "program: #{$0}\n"
	end
	
	def test_BASIC_00010_Test_Register
		begin 
	    func = SAPNW::RFC::FunctionDescriptor.new("RFC_REMOTE_PIPE")
			pipedata = SAPNW::RFC::Type.new({:name => 'DATA', 
			                                 :type => SAPNW::RFC::TABLE,
																			 :fields => [{:name => 'LINE',
																			              :type => SAPNW::RFC::CHAR, 
																			              :len => 80}
																									]
																			})
		  func.addParameter(SAPNW::RFC::Export.new(:name => "COMMAND", :len => 80, :type => SAPNW::RFC::CHAR))
		  func.addParameter(SAPNW::RFC::Table.new(:name => "PIPEDATA", :len => 80, :type => pipedata))
		  $stderr.print "Built up FunctionDescriptor: #{func.inspect}/#{func.parameters.inspect}\n"
			pass = 0
	    func.callback = Proc.new do |fc|
		    $stderr.print "#{fc.name} got called with #{fc.COMMAND}\n"
				if /^blah/.match(fc.COMMAND)
				  raise SAPNW::RFC::ServerException.new({'error' => "Got Blah", 'code' => 111, 'key' => "RUBY_RUNTIME", 'message' => "Got a blah message" })
				end
				call = `#{fc.COMMAND}`
				fc.PIPEDATA = []
				call.split(/\n/).each do |val|
				  fc.PIPEDATA.push({'LINE' => val})
				end
				pass += 1
				$stderr.print "pass: #{pass}\n"
        # dont ever "return" inside a callback - or it just exits 
				#   make the last value true or nil depending on whether 
				#   you successfully handled callback or not
				true
		  end
		  $stderr.print "Register...\n"
	    assert(server = SAPNW::Base.rfc_register)
	    attrib = server.connection_attributes
	    SAP_LOGGER.warn "Connection Attributes: #{attrib.inspect}\n"
		  $stderr.print "Install...\n"
	    assert(server.installFunction(func))
	    globalCallBack = Proc.new do |attrib|
	  	  $stderr.print "global got called: #{attrib.inspect}\n"
				if pass < 150
	  		  true
				else
				  # will tell the accept() loop to exit
				  false
				end
	  	end
		  $stderr.print "Accept...\n"
	  	server.accept($WAIT, globalCallBack)
	  rescue SAPNW::RFC::ServerException => e
	    SAP_LOGGER.warn "ServerException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  rescue SAPNW::RFC::FunctionCallException => e
	    SAP_LOGGER.warn "FunctionCallException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  rescue SAPNW::RFC::ConnectionException => e
	    SAP_LOGGER.warn "ConnectionException ERROR: #{e.inspect} - #{e.error.inspect}\n"
	  end
	end
	
	def teardown
	end
end
