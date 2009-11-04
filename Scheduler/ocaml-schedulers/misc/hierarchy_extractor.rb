#!/usr/bin/ruby
require 'sequel'

DB = Sequel.mysql(
  "oar",
  :user=>"oar",
  :password=>"oar",  
  :host => "localhost"  
 )

$DEFAULT_LABELS = ['resource_id','cluster','switch','node','cpu','core']

$hierarchy_labels = []
$hierarchy_set = DB["SELECT * FROM resources"]

$fields = DB[:resources].columns

def idemize(s)
  m =-1
  nb = 1
  b=[]
  v=[]
  s.each do |n|
    if (m==n) then
      nb = nb + 1
    else
      b << nb
      v << m
      m = n
      nb = 1
    end
  end
  b << nb
  v << m
  [b[1..b.size], v[1..b.size]]
end

def h_synth(s)
  h=[]
  b,v = idemize(s)
  nb_block,block_size = idemize(b)
  id =1
  nb_block.each_with_index do |nb,i|
    #puts "#{id},#{block_size[i]},#{nb}"
    h << "(#{id},#{block_size[i]},#{nb})"
    id = id + nb * block_size[i] * nb
  end
  h.join(',')    
end

#HIERARCHY_LABELS="node,cpu,core"
#node="(1,16,2), (32,8,4)"
#cpu="(1,8,8)"
#core="(1,1,64)"

if ARGV.length == 0
  $hierarchy_labels = $DEFAULT_LABELS 
else
  $hierarchy_labels = ARGV.first.split(',')
end

h_labels = "HIERARCHY_LABELS=\""
h_desc = ""

$hierarchy_labels.each do |label|
  sym_label = label.to_sym
  if $fields.include?(sym_label)
    h_level = h_synth($hierarchy_set.map(sym_label))
    h_desc << "#{label}=\"#{h_level}\”\n"
    h_labels << label << ',' 
  end
end
 
h_labels.chop! << '"'

puts h_labels
puts h_desc


#f = IO.readlines("oar.conf")

#f.each do |l| 
#  if !(l =~ /^#/) then
#    l =~  /^(.*)=(.*)\s*/
#    puts l,$2
#  end
#end
