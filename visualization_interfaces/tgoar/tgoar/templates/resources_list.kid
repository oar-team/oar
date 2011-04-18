<html  xmlns:py="http://purl.org/kid/ns#" py:extends="'welcome.kid'">
<head>
    <title>Resources list</title>
    <link rel="stylesheet" type="text/css" href="/static/css/style.css" media="screen" />
    <script src="${tg.tg_js}/MochiKit.js" />
</head>
<body>

<div id="top" py:content='title()'></div>
<div id="topmenu" py:content='menu()'></div>


<div id="subheader">
    <h1>Resources</h1>
    <ul>
        <li py:if="display_type != 'compact'">
            <a href="${tg.url('/resources/?display_type=compact')}">Compact view</a>
        </li>
        <li py:if="display_type != 'list'">
            <a href="${tg.url('/resources/?display_type=list')}">List view</a>
        </li>
    </ul>
</div>

<div id="main" py:if="display_type=='list'">
    <table id="resource_desc" class="list_table">
        <tr id="thead">
            <td py:for="field in resources[0]" py:if="field['visible'] == True">
        
                <a py:if="field['name'] != 'running'" href="${tg.url('/resources/?sf=' + field['name'])}&amp;so=a">^</a>
                <a py:if="field['name'] != 'running'" href="${tg.url('/resources/?sf=' + field['name'])}&amp;so=d">v</a>
                ${field['desc']}
            </td>
            <td>
            </td>
        </tr>
        <tr class="tline" py:for="r in resources[1]">
<?python
    j=0
    line = []
    classs= "" 
    for i in r:
        if resources[0][j]['visible']: 
            line = line + [ i ]
        if resources[0][j]['name'] == 'state':
            if r[j] == 'Suspected':
                classs = 'suspect_line'
            elif r[j] == 'Alive':
                classs = 'alive_line'
            elif r[j] == 'Dead':
                classs == 'dead_line'
            elif r[j] == 'Absent':
                classs = 'absent_line'
        j=j+1 
    
    j=0
    for i in r:
        if resources[0][j]['name'] == 'running':
           if r[j] == "Running":
               classs = 'running_line'
        j=j+1
    
    def get_val_by_name(line, name):
        j = 0 
?>
            <td py:for="v in line" class="${classs}">
                ${v}
            </td>
            <td>
                <a href="${tg.url( '/resources/resource?resource_id='+str(r[0]))}">View</a>
            </td>
        </tr>
    </table>
</div>


<div id="main" py:if="display_type=='compact'">
<?python
from math import sqrt

maxwidth = 20

w = int(sqrt(len(resources[1]))) 
if w >= maxwidth: 
    w = maxwidth
else:
    h = w

h = int(len(resources[1])/w) + 1 

print "w=" + str(w) + "h=" + str(h)

state_index = 0 
run_index = 0
host_index = 0

si=0
ri=0
hi=0
for i in resources[0]:
    print i
    if i['name'] == 'state':
        state_index = si
    elif i['name'] == 'running':
        run_index = ri
    elif i['name'] == 'network_address':
        host_index = hi
    si = si + 1
    ri = ri + 1
    hi = hi + 1

d = 0 
e = 0 

?>
    <table class="compact_table">
    
        <tr py:for="i in range(h)">
            <td py:for="j in range(w)">
            <?python
            c = "" 
            if d < len(resources[1]):
                state = resources[1][d][state_index]
                running = resources[1][d][run_index]
                host = resources[1][d][host_index]

                if state == 'Suspected':
                    c = 'suspect_line'
                elif state == 'Alive': 
                    c = 'alive_line'
                elif state == 'Dead':
                    c = 'dead_line'
                elif state == 'Absent':
                    c = 'absent_line'

                if running == 'Running':
                    c = 'running_line'
                e = e + 1 
            else:
                c = "none"
                host = ""
                
            d = d+1
            print d
            ?>
            <span class="${c}">
                <a href="${tg.url('/resources/resource?resource_id=')}${resources[1][e-1][0]}" py:if="e == d">${host}</a>
            </span>
            </td>
        </tr>
    </table>
</div>




<div id="footer" py:content="footer()" />
</body>
</html>
