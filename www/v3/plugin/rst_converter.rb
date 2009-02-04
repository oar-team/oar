class RstConverterTag < Tags::DefaultTag

	infos(
		:name => 'Tag/RstConverter',
		:summary => "Allows website tracking thanks to Google Analytics ga.jscode",
		:author => "Olivier Richard"
		)

	param 'rstfile', nil, 'The rst file to converte'
	param 'path', '.', 'The path to rst file'
	set_mandatory 'rstfile', true
	register_tag 'rstconverter'

	def process_tag(tag, chain)

		rstfile = param('rstfile').split(',')

		files = ""
		rstfile.each do |filename|
			files = files + " " + param('path') + '/' + filename
		end

#		if  File.exist?( param('path') + '/' + rstfile[0] )
#			content = `cd rst_files ; ls `
			content = `cd rst_files ; cat #{files} | rst2html | egrep -v '^<\/body>|^<body>|^<!DOCTYPE|^<html xmlns|^<head>|^<\/head>|^<meta|^<title>|^<link|^</\html>'`
#		else
#		  log(:error) { "#{param('path') + '/' + rstfile[0]}  file doesn't exist"}
#			content = ''
#		end

		return content
	end
end
