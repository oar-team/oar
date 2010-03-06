class RstConverterTag < Tags::DefaultTag

	infos(
		:name => 'Tag/RstConverter',
		:summary => "Allows website tracking thanks to Google Analytics ga.jscode",
		:author => "Olivier Richard"
		)

	param 'rstfile', nil, 'The rst file to convert'
	param 'path', '.', 'The path to rst file'
	set_mandatory 'rstfile', true
	register_tag 'rstconverter'

  @@rst_files_already_processed = {} 

	def process_tag(tag, chain)

puts tag
		rstfile = param('rstfile').split(',')

		files = ""
		rstfile.each do |filename|
			files = files + " " + param('path') + '/' + filename
		end

    if !(@@rst_files_already_processed.key?(files)) then 
#if true then

#		if  File.exist?( param('path') + '/' + rstfile[0] )
#			content = `cd rst_files ; ls `
      puts "rstconvert files:  #{files}"
			content = `cd rst_files ; cat #{files} | rst2html | egrep -v '^<\/body>|^<body>|^<!DOCTYPE|^<html xmlns|^<head>|^<\/head>|^<meta|^<title>|^<link|^</\html>'`
#		else
#		  log(:error) { "#{param('path') + '/' + rstfile[0]}  file doesn't exist"}
#			content = ''
#		end
      @@rst_files_already_processed[files] = content
    else
      puts "already processed: #{files}"
      #content = @@rst_files_already_processed[files]
      @@rst_files_already_processed.delete(files)
  #   puts content
      content= ""
    end
		return content
	end
end
