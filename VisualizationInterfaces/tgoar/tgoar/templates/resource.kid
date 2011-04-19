<html  xmlns:py="http://purl.org/kid/ns#" py:extends="'welcome.kid'">
    <head>
        <title>Resource property</title>
        
        <link rel="stylesheet" type="text/css" href="/static/css/style.css" media="screen" />
    </head>
    <body>

<!-- Widgets definition  ########################################################## -->

<div class="property_table" py:def="node_property(resource)"> 
    <h1 class="section_title">Node Properties</h1>
    <table class="list_table">
        <tr py:for="prop in resource" py:if="prop['visible']">
            <td class="property">${prop['desc']}</td>
            <td class="value">${prop['value']}</td>
        </tr>
    </table>
</div>

<!--  End of Widgets definition ################################################## -->


        
        <div py:content='title()' />
        <div py:content='menu()' />
        
        <div id="subheader" py:if="error_flag==1"> 
            <span class="error_banner">Error: no such resource</span>
        </div>
        
        <div id="subheader" py:if="error_flag==0">
            <h1>Resource informations</h1>
        </div>


        <div id="main" py:if="error_flag==0">

            
            <div py:content='node_property(resource)' />
            
            
            <div id="resource_jobs">
                <h1 class="section_title">Scheduled jobs</h1>
                
                <table class="list_table" id="jobs">
                    <tr id="thead">
                        <td py:for="field in jobs[0]" py:if="field['visible']">${field['desc']}</td>
                    </tr>
                    <tr py:for="job in jobs[1]">
                        <?python
    j=0
    jline = []
    classs= ""
    for i in job:
        if jobs[0][j]['name'] == 'state':
            if job[j] == "Running":
                classs = 'running_line'

        if jobs[0][j]['visible'] == True:
            jline = jline + [ i ]
        j=j+1
    print jline
?>
                        <td py:for="value in jline" class="${classs}">
                            ${value}
                        </td>
                    </tr>
                </table>
            </div>
            
            
            
            
            <div id="resource_logs">
                <h1 class="section_title">Node Logs</h1>
                <table class="list_table" id="resource_logs">
                    <tr id="thead">
                        <td py:for="field in resource_logs[0]" py:if="field['visible']">${field['desc']}</td>
                    </tr>
                    <tr py:for="logline in resource_logs[1]" class="tline">
                        <?python
    j=0
    line = []
    classs= "" 
    for i in logline:
        if resource_logs[0][j]['visible']: 
            line = line + [ i ]
        j=j+1
    
?>
                        <td py:for="value in line">
                            ${value}
                        </td>
                    </tr>
                </table>
            </div>
            
        </div>
        
        
        <div id="footer" py:content="footer()" />
    </body>
</html>
