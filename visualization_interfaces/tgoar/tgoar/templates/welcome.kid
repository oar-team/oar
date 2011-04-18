<html  xmlns:py="http://purl.org/kid/ns#">
<head>
    <title>Wellcome on tgoar</title>
    <link rel="stylesheet" type="text/css" href="/static/css/style.css" media="screen" />
</head>
<body>
<div id="top" py:def="title()">
    <h1>TGOAR - Oar web interface</h1>
</div>
<div id="topmenu" py:def="menu()">
    <ul>
        <li><a href="${tg.url('/resources/')}">List resources</a></li>
    </ul>
    <ul>
        <li></li>
<!--        <li><a href="http://gforge.inria.fr/projects/pipol">PIPOL forge</a></li>-->
    </ul>
    <ul>
        <li><a href="${tg.url('/static/help.html')}">Help</a></li>
    </ul>
</div>




<div py:content="title()" />
<div py:content="menu()" />


<div id="subheader">
    Wellcome
</div>

<div id="main">
    -
</div>

<div id="footer" py:def="footer()">
<p>TGOAR<br />
<a href="http://validator.w3.org/check?uri=referer" title="Validate">XHTML</a> - <a href="http://jigsaw.w3.org/css-validator/check/referer" title="Validate">CSS</a>
</p>
</div>

</body>
</html>
