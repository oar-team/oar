#!/usr/bin/ruby -w
require 'cgi'
require 'net/http'
require 'uri'
require 'yaml'

$verbose = false

MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
DAYS = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
RANGE_ORDER = ['1/6 day','1/2 day','1 day','3 days','week','month']
RANGE_SEC = {'1/6 day'=>14400,'1/2 day'=>43200,'1 day'=>86400,'3 days'=>259200,'week'=>604800,'month'=>2678400,'year'=>31622400}
RANGE_STEP = {'1/6 day'=>3600,'1/2 day'=>10800,'1 day'=>43200,'3 days'=>86400,'week'=>345600,'month'=>604800}

CONF_FILE = '/etc/oar/oargridgantt.conf'

$conf = YAML::load(IO::read(CONF_FILE))
$mp_conf = $conf['main_page']
$title = $mp_conf['title']

def create_conf(site)
	conf = $conf.clone
	conf['sites'][site].each { |key,value| conf[key]=value.clone }
	conf.delete('sites')
	conf.delete('main_page')
	return conf
end

def get_map(generated_files)
	threads = []
	map = ''
	maps = {}
	$conf['sites'].each do |site,params|
		if !generated_files[site].nil?
			threads << Thread.new(site) do |s|
				path_map = params['path_map'] || ''
				map_reponse  = Net::HTTP.get_response(params['server'],"/#{path_map}/#{generated_files[s][1]}".gsub(/\/+/,'/'))
				if map_reponse.code == "200"
					if params['url_monika'].nil?
						maps[s] = map_reponse.body
					else
						maps[s] = map_reponse.body.gsub(/monika.cgi/,params['url_monika']) 
					end
				else
					$stderr.print "#{params['server']}/#{path_map}/#{generated_files[s][1]}".gsub(/\/+/,'/')
					$stderr.print "Can't retrieve file map: " + map_reponse.code 
				end
			end
		end
	end
	threads.each {|thr| thr.join }
	maps.each { |key,value| map << value }
	return map
end

def call_remote_cgi(remote_cgi_paramters)
	threads = []
	generate_files = {}
	remote_cgi_paramters['mode'] =  'image_map_only'

	$conf['sites'].each do |site,params|
		remote_cgi_params = remote_cgi_paramters.clone
		remote_cgi_params['prefix'] = site
		remote_cgi_params['path'] = params['path'] if  !params['path'].nil?
		conf = create_conf(site)
		remote_cgi_params['conf'] = "#{conf.to_yaml}"

		threads << Thread.new(remote_cgi_params) do |cgi_parameters|
			path_cgi = params['path_cgi'] || 'cgi-bin/drawgantt.cgi'

	#		puts  "http://#{params['server']}/#{path_cgi}"
			partial_url = "/#{params['server']}/#{path_cgi}".gsub(/\/+/,'/')
			response = Net::HTTP.post_form URI.parse("http:/#{partial_url}"), cgi_parameters

			if response.code == '200'
				generate_files[site] = response.body.split(/\n/)
			else
				$stderr.print "http:/#{partial_url}"
				$stderr.print "Error in remote generaton: " + response.code
			end
		end
	end

	threads.each {|thr| thr.join }

	return generate_files
end

def cgi_html(cgi)

	remote_cgi_paramters = {}
	
	popup_hour = ["00:00","01:00","02:00","03:00","04:00","05:00","06:00","07:00","08:00","09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00","19:00","20:00","21:00","22:00","23:00"]
	popup_day = ["1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31"]
	popup_month = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct', 'Nov','Dec']
	popup_year = []
	popup_range = RANGE_ORDER

	range = $mp_conf['default_range']

	now = Time.now

	month, day, hour, year = now.strftime("%b %e %H:00 %Y").split(" ")
	popup_year = [(year.to_i-2).to_s, (year.to_i-1).to_s, year, (year.to_i+1).to_s ]

	origin = 0

	if (cgi.params['day'].length>0)
		hour = cgi.params['hour'].to_s
		day	= cgi.params['day'].to_s
		month = cgi.params['month'].to_s
		year = cgi.params['year'].to_s
		range = cgi.params['range'].to_s
		origin =  Time.local(year,month,day,hour).to_i
	else
		range = $mp_conf['default_range']
		origin = now.to_i-RANGE_SEC[range]/2
	end	

	#
	# zoom +-, left,rigth, default ?
	#
	if (cgi.params['plus.x'].length>0)
		if (range != RANGE_ORDER.first)
			next_range = RANGE_ORDER[RANGE_ORDER.index(range) - 1]
			origin = origin + (RANGE_SEC[range] - RANGE_SEC[next_range]) / 2
			range = next_range  
		end
	end

	if (cgi.params['minus.x'].length>0)
		if (range != RANGE_ORDER.last)
			next_range = RANGE_ORDER[RANGE_ORDER.index(range) + 1]
			origin = origin + (RANGE_SEC[range] - RANGE_SEC[next_range]) / 2
			range = next_range  
		end
	end

	if (cgi.params['left.x'].length>0)
		origin = origin - RANGE_STEP[range]
	end

	if (cgi.params['right.x'].length>0)
		origin = origin + RANGE_STEP[range]
	end

	if (cgi.params['action'].to_s == 'Default')
		range = $mp_conf['default_range']
		origin = now.to_i-RANGE_SEC[range]/2
	end

	if (range == '3 days') || (range == 'week') || (range == 'month')
#		origin = origin - origin % 86400 - Time.at(origin).gmt_offset
		origin = origin - origin % 86400
	else
 		origin = origin - origin % 3600
	end
	
	wday, month, day, hour, year = Time.at(origin).strftime("%a %b %e %H:00 %Y").split(" ")

	remote_cgi_paramters['hour'] = hour

	remote_cgi_paramters['day'] = day
	remote_cgi_paramters['month'] = month
	remote_cgi_paramters['year'] = year
	remote_cgi_paramters['range'] = range

	
	#set displaying params
	popup_year[popup_year.index(year)]= [year,true]
	popup_month[popup_month.index(month)]= [month,true]
	popup_day[popup_day.index(day)]= [day,true]
	popup_hour[popup_hour.index(hour)]= [hour,true]
	popup_range[popup_range.index(range)]= [range,true]

	#launch remote building of image and map files
	generate_files = call_remote_cgi(remote_cgi_paramters)
#	puts "###########"
#	p generate_files
	map = get_map(generate_files)
	
	#set url_base_image
	url_base_image = {}
	$conf['sites'].each do |site,params|
		url_base_image[site] = params['url_base_image'] || "http://#{params['server']}"
		if generate_files[site].nil?
			generate_files[site] = ["image_unavailable"] if generate_files[site].nil?
		else
			generate_files[site][0] = "/#{generate_files[site][0]}".gsub(/\/+/,'/')
		end
	end
	

  cgi.out {
	  cgi.html {
		  cgi.head { "\n"+cgi.title{$title} } +			
		  cgi.body { "\n"+
			  cgi.form("get"){
				  cgi.h3 { $title } + "\n"+
				  # Javascript stuff borrowed from NCSA TITAN cluster's page    
				  CGI.escapeElement('<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>') + "\n" +
				  CGI.escapeElement('<script src="/'+"#{$mp_conf['directory']}"+'/'+"#{$mp_conf['web_path_js_directory']}" +
					  								'/overlib.js" language="JavaScript"></script>') + "\n" +
				  CGI.escapeElement("<em> Origin </em>") +
				  cgi.popup_menu("NAME" => "year", "VALUES" => popup_year) +
				  cgi.popup_menu("NAME" => "month", "VALUES" => popup_month) +
				  cgi.popup_menu("NAME" => "day", "VALUES" => popup_day) +
					cgi.popup_menu("NAME" => "hour", "VALUES" => popup_hour) +	
					CGI.escapeElement("<em> Range </em>") +
					cgi.popup_menu("NAME" => "range", "VALUES" => popup_range) +
					cgi.submit("Draw","action") +
					cgi.submit("Default","action") +
					cgi.image_button("/#{$mp_conf['directory']}/#{$mp_conf['web_icons_directory']}/gorilla-left.png", "left", "left") +
					cgi.image_button("/#{$mp_conf['directory']}/#{$mp_conf['web_icons_directory']}/gorilla-right.png", "right", "right") +
					cgi.image_button("/#{$mp_conf['directory']}/#{$mp_conf['web_icons_directory']}/gorilla-minus.png", "minus", "minus") +
					cgi.image_button("/#{$mp_conf['directory']}/#{$mp_conf['web_icons_directory']}/gorilla-plus.png", "plus", "plus") +
					cgi.br + "\n" +
					CGI.escapeElement(map) + "\n" + 
					$mp_conf['sites_displaying_order'].collect { |site|
						cgi.h3 { site } + "\n" +
						CGI.escapeElement('<div style="text-align: center">') +
						cgi.img("SRC" => "#{url_base_image[site]}#{generate_files[site][0]}",
										"ALT" => "gantt image", "USEMAP" => "##{site}_ganttmap" ) +
						CGI.escapeElement('</div>')
					}.join
				}
			}
		}
	}
end 


#################################################################################################################
### main
#################################################################################################################

cgi = CGI.new("html3")

#conf 

cgi_html(cgi)
