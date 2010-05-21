/* global Ext */
/* @class Ext.ux.ManagedIFrame
 * Version:  1.2
 * Author: Doug Hendricks. doug[always-At]theactivegroup.com
 * Copyright 2007-2008, Active Group, Inc.  All rights reserved.
 *
 ************************************************************************************
 *   This file is distributed on an AS IS BASIS WITHOUT ANY WARRANTY;
 *   without even the implied warranty of MERCHANTABILITY or
 *   FITNESS FOR A PARTICULAR PURPOSE.
 ************************************************************************************

 License: ux.ManagedIFrame and ux.ManagedIFramePanel 1.2 are licensed under the terms of
 the Open Source LGPL 3.0 license: http://www.gnu.org/licenses/lgpl.html

 Commercial use is prohibited without a Commercial License. See http://licensing.theactivegroup.com.

 Donations are welcomed: http://donate.theactivegroup.com

 * <p> An Ext.Element harness for iframe elements.

  Adds Ext.UpdateManager(Updater) support and a compatible 'update' method for
  writing content directly into an iFrames' document structure.

  Signals various DOM/document states as the frames content changes with 'domready',
  'documentloaded', and 'exception' events.  The domready event is only raised when
  a proper security context exists for the frame's DOM to permit modification.
  (ie, Updates via Updater or documents retrieved from same-domain servers).

  Frame sand-box permits eval/script-tag writes of javascript source.
  (See execScript, writeScript, and loadFunction methods for more info.)

  * Usage:<br>
   * <pre><code>
   * // Harnessed from an existing Iframe from markup:
   * var i = new Ext.ux.ManagedIFrame("myIframe");
   * // Replace the iFrames document structure with the response from the requested URL.
   * i.load("http://myserver.com/index.php", "param1=1&amp;param2=2");

   * // Notes:  this is not the same as setting the Iframes src property !
   * // Content loaded in this fashion does not share the same document namespaces as it's parent --
   * // meaning, there (by default) will be no Ext namespace defined in it since the document is
   * // overwritten after each call to the update method, and no styleSheets.
  * </code></pre>
  * <br>
   * @cfg {Boolean/Object} autoCreate True to auto generate the IFRAME element, or a {@link Ext.DomHelper} config of the IFRAME to create
   * @cfg {String} html Any markup to be applied to the IFRAME's document content when rendered.
   * @cfg {Object} loadMask An {@link Ext.LoadMask} config or true to mask the iframe while using the update or setSrc methods (defaults to false).
   * @cfg {Object} src  The src attribute to be assigned to the Iframe after initialization (overrides the autoCreate config src attribute)
   * @constructor
  * @param {Mixed} el, Config object The iframe element or it's id to harness or a valid config object.

 * Release: 1.2  (8/22/2008) FF3 Compatibility Fixes, loadMask tweaks

            1.1  (4/13/2008) Adds Ext.Element, CSS Selectors (query,select) fly, and CSS
                                    interface support (same-domain only)
                              Adds blur,focus,unload events (same-domain only)

  */

(function(){

var EV = Ext.lib.Event;

Ext.ux.ManagedIFrame = function(){
    var args=Array.prototype.slice.call(arguments, 0)
        ,el = Ext.get(args[0])
        ,config = args[0];

    if(el && el.dom && el.dom.tagName == 'IFRAME'){
            config = args[1] || {};
    }else{
            config = args[0] || args[1] || {};

            el = config.autoCreate?
            Ext.get(Ext.DomHelper.append(config.autoCreate.parent||document.body,
                Ext.apply({tag:'iframe', src:(Ext.isIE&&Ext.isSecure)?Ext.SSL_SECURE_URL:''},config.autoCreate))):null;
    }

    if(!el || el.dom.tagName != 'IFRAME') return el;

    el.dom.name || (el.dom.name = el.dom.id); //make sure there is a valid frame name

    el.dom.mifId = el.dom.id; //create an un-protected reference for browsers which prevent access to 'id'(FF3).

    this.addEvents({
        /**
         * @event focus
         * Fires when the frame gets focus.
         * @param {Ext.ux.ManagedIFrame} this
         * @param {Ext.Event}
         * Note: This event is only available when overwriting the iframe document using the update method and to pages
         * retrieved from a "same domain".
         * Returning false from the eventHandler [MAY] NOT cancel the event, as this event is NOT ALWAYS cancellable in all browsers.
         */
        "focus"         : true,

        /**
         * @event blur
         * * Fires when the frame is blurred (loses focus).
         * @param {Ext.ux.ManagedIFrame} this
         * @param {Ext.Event}
         * Note: This event is only available when overwriting the iframe document using the update method and to pages
         * retrieved from a "same domain".
         * Returning false from the eventHandler [MAY] NOT cancel the event, as this event is NOT ALWAYS cancellable in all browsers.
         */
        "blur"          : true,

        /**
         * @event unload
         * * Fires when(if) the frames window object raises the unload event
         * @param {Ext.ux.ManagedIFrame} this
         * @param {Ext.Event}
         * Note: This event is only available when overwriting the iframe document using the update method and to pages
         * retrieved from a "same domain".
         * Note: Opera does not raise this event.
         */
        "unload"        : true,

       /**
         * @event domready
         * Fires ONLY when an iFrame's Document(DOM) has reach a state where the DOM may be manipulated (ie same domain policy)
         * @param {Ext.ux.ManagedIFrame} this
         * Note: This event is only available when overwriting the iframe document using the update method and to pages
         * retrieved from a "same domain".
         * Returning false from the eventHandler stops further event (documentloaded) processing.
         */
        "domready"       : true,

       /**
         * @event documentloaded
         * Fires when the iFrame has reached a loaded/complete state.
         * @param {Ext.ux.ManagedIFrame} this
         */
        "documentloaded" : true,

        /**
         * @event exception
         * Fires when the iFrame raises an error
         * @param {Ext.ux.ManagedIFrame} this
         * @param {Object/string} exception
         */
        "exception" : true,
        /**
         * @event message
         * Fires upon receipt of a message generated by window.sendMessage method of the embedded Iframe.window object
         * @param {Ext.ux.ManagedIFrame} this
         * @param {object} message (members:  type: {string} literal "message",
         *                                    data {Mixed} [the message payload],
         *                                    domain [the document domain from which the message originated ],
         *                                    uri {string} the document URI of the message sender
         *                                    source (Object) the window context of the message sender
         *                                    tag {string} optional reference tag sent by the message sender
         */
        "message" : true
        /**
         * Alternate event handler syntax for message:tag filtering
         * @event message:tag
         * Fires upon receipt of a message generated by window.sendMessage method
         * which includes a specific tag value of the embedded Iframe.window object
         * @param {Ext.ux.ManagedIFrame} this
         * @param {object} message (members:  type: {string} literal "message",
         *                                    data {Mixed} [the message payload],
         *                                    domain [the document domain from which the message originated ],
         *                                    uri {string} the document URI of the message sender
         *                                    source (Object) the window context of the message sender
         *                                    tag {string} optional reference tag sent by the message sender
         */
        //"message:tagName"  is supported for X-frame messaging
    });

    if(config.listeners){
        this.listeners=config.listeners;
        Ext.ux.ManagedIFrame.superclass.constructor.call(this);
    }

    Ext.apply(el,this);  // apply this class interface ( pseudo Decorator )

    el.addClass('x-managed-iframe');
    if(config.style){
        el.applyStyles(config.style);
    }

    el._maskEl = el.parent('.x-managed-iframe-mask')||el.parent().addClass('x-managed-iframe-mask');

    Ext.apply(el,{
      disableMessaging : config.disableMessaging===true
     ,loadMask         : Ext.apply({msg:'Loading..'
                            ,msgCls:'x-mask-loading'
                            ,maskEl: el._maskEl
                            ,hideOnReady:true
                            ,disabled:!config.loadMask},config.loadMask)
    //Hook the Iframes loaded state handler
     ,_eventName       : Ext.isIE?'onreadystatechange':'onload'
     ,_windowContext   : null
     ,eventsFollowFrameLinks  : typeof config.eventsFollowFrameLinks=='undefined'?
                                true  :  config.eventsFollowFrameLinks
    });

    el.dom[el._eventName] = el.loadHandler.createDelegate(el);

    var um = el.updateManager=new Ext.UpdateManager(el,true);
    um.showLoadIndicator= config.showLoadIndicator || false;

    if(config.src){
        el.setSrc(config.src);
    }else{

        var content = config.html || config.content || false;

        if(content){
            el.update.defer(10,el,[content]); //allow frame to quiesce
        }
    }

    return Ext.ux.ManagedIFrame.Manager.register(el);

};

var MIM = Ext.ux.ManagedIFrame.Manager = function(){
  var frames = {};

   //private DOMFrameContentLoaded handler for browsers that support it.
  var readyHandler = function(e, target){
         //use the unprotected DOM Id reference first

        try{
            var id =target?target.mifId:null, frame;
            if((frame = this.getFrameById(id || target.id)) && frame._frameAction){
                frame.loadHandler({type:'domready'});
            }

        }catch(rhEx){}

    };

  var implementation= {
    shimCls      : 'x-frame-shim',
    register     :function(frame){
        frame.manager = this;
        frames[frame.id] = frames[frame.dom.name] = {ref:frame, elCache:{}};
        return frame;
    },

    deRegister     :function(frame){

        frame._unHook();
        delete frames[frame.id];
        delete frames[frame.dom.name];

    },
    hideShims : function(){

        if(!this.shimApplied)return;
        Ext.select('.'+this.shimCls,true).removeClass(this.shimCls+'-on');
        this.shimApplied = false;
    },

    /* Mask ALL ManagedIframes (eg. when a region-layout.splitter is on the move.)*/
    showShims : function(){
       if(!this.shimApplied){
          this.shimApplied = true;
          //Activate the shimCls globally
          Ext.select('.'+this.shimCls,true).addClass(this.shimCls+'-on');
       }

    },
    getFrameById  : function(id){
       return typeof id == 'string'?(frames[id]?frames[id].ref||null:null):null;
    },

    getFrameByName : function(name){
        return this.getFrameById(name);
    },

    //retrieve the internal frameCache object
    getFrameHash  : function(frame){
       return frame.id?frames[frame.id]:null;

    },

    //to be called under the scope of the managing MIF
    eventProxy     : function(e){

        if(!e)return;
        e = Ext.EventObject.setEvent(e);
        var be=e.browserEvent||e;

        //same-domain unloads should clear ElCache for use with the next document rendering
        if(e.type == 'unload'){ this._unHook(); }

        if(!be['eventPhase'] || (be['eventPhase'] == (be['AT_TARGET']||2))){
            return this.fireEvent(e.type, e);
        }
    },

    _flyweights : {},

    destroy : function(){
      if(this._domreadySignature  ){
        Ext.EventManager.un.apply(Ext.EventManager,this._domreadySignature);
       }

    },

    //safe removal of embedded frame elements
    removeNode : Ext.isIE ?
               function(frame, n){
                    frame = MIM.getFrameHash(frame);
                    if(frame && n && n.tagName != 'BODY'){
                        d = frame.scratchDiv || (frame.scratchDiv = frame.getDocument().createElement('div'));
                        d.appendChild(n);
                        d.innerHTML = '';
                    }
                }
              : function(frame, n){
                    if(n && n.parentNode && n.tagName != 'BODY'){
                        n.parentNode.removeChild(n);
                    }
                }

   };
   if(document.addEventListener){  //for Gecko and Opera and any who might support it later
       Ext.EventManager.on.apply(Ext.EventManager,implementation._domreadySignature=[window,"DOMFrameContentLoaded", readyHandler , implementation]);
   }

   Ext.EventManager.on(window,'beforeunload', implementation.destroy, implementation);
   return implementation;


 }();

 MIM.showDragMask = MIM.showShims;
 MIM.hideDragMask = MIM.hideShims;

 //Provide an Ext.Element interface to frame document elements
 MIM.El =function(frame, el, forceNew){

     var frameObj;
     frame = (frameObj = MIM.getFrameHash(frame))?frameObj.ref:null ;

     if(!frame ){ return null; }
     var elCache = frameObj.elCache || (frameObj.elCache = {});

     var dom = frame.getDom(el);

     if(!dom){ // invalid id/element
         return null;
     }
     var id = dom.id;
     if(forceNew !== true && id && elCache[id]){ // element object already exists
         return elCache[id];
     }

     /**
      * The DOM element
      * @type HTMLElement
      */
     this.dom = dom;

     /**
      * The DOM element ID
      * @type String
      */
    this.id = id || Ext.id(dom);
 };

 MIM.El.get =function(frame, el){
     var ex, elm, id, doc;
     if(!frame || !el ){ return null; }

     var frameObj;
     frame = (frameObj = MIM.getFrameHash(frame))?frameObj.ref:null ;

     if(!frame ){ return null;}

     var elCache = frameObj.elCache || (frameObj.elCache = {} );

     if(!(doc = frame.getDocument())){ return null; }
     if(typeof el == "string"){ // element id
         if(!(elm = frame.getDom(el))){
             return null;
         }
         if(ex = elCache[el]){
             ex.dom = elm;
         }else{
             ex = elCache[el] = new MIM.El(frame, elm);
         }
         return ex;
     }else if(el.tagName){ // dom element
         if(!(id = el.id)){
             id = Ext.id(el);
         }
         if(ex = elCache[id]){
             ex.dom = el;
         }else{
             ex = elCache[id] = new MIM.El(frame, el);
         }
         return ex;
     }else if(el instanceof MIM.El){
         if(el != frameObj.docEl){
             el.dom = frame.getDom(el.id) || el.dom; // refresh dom element in case no longer valid,
                                                     // catch case where it hasn't been appended
             elCache[el.id] = el; // in case it was created directly with Element(), let's cache it
         }
         return el;
     }else if(el.isComposite){
         return el;
     }else if(Ext.isArray(el)){
         return frame.select(el);
     }else if(el == doc){
         // create a bogus element object representing the document object
         if(!frameObj.docEl){
             var f = function(){};
             f.prototype = MIM.El.prototype;
             frameObj.docEl = new f();
             frameObj.docEl.dom = doc;
         }
         return frameObj.docEl;
     }
    return null;

 };

 Ext.apply(MIM.El.prototype,Ext.Element.prototype);

 Ext.extend(Ext.ux.ManagedIFrame , Ext.util.Observable,
    {

    src : null ,

    resetUrl :Ext.isIE&&Ext.isSecure?Ext.SSL_SECURE_URL: 'about:blank' ,
      /**
      * Sets the embedded Iframe src property.

      * @param {String/Function} url (Optional) A string or reference to a Function that returns a URI string when called
      * @param {Boolean} discardUrl (Optional) If not passed as <tt>false</tt> the URL of this action becomes the default SRC attribute for
      * this iframe, and will be subsequently used in future setSrc calls (emulates autoRefresh by calling setSrc without params).
      * Note:  invoke the function with no arguments to refresh the iframe based on the current src value.
     */
    setSrc : function(url, discardUrl, callback){

          var src = url || this.src || this.resetUrl;

          this._windowContext = null;
          this._unHook();
          this._frameAction = this.frameInit= this._domReady =false;

          if(Ext.isOpera){ this.reset(); }

          this._callBack = callback || false;

          this.showMask();

          (function(){
                var s = typeof src == 'function'?src()||'':src;
                try{
                    this._frameAction = true; //signal listening now
                    this.dom.src = s;
                    this.frameInit= true; //control initial event chatter
                    this.checkDOM();
                }catch(ex){ this.fireEvent('exception', this, ex); }

          }).defer(100,this);

          if(discardUrl !== true){ this.src = src; }

          return this;

    },
    reset     : function(src, callback){
          this.dom.src = src || this.resetUrl;
          if(typeof callback == 'function'){ callback.defer(100);}
          return this;

    },
    //Private: script removal RegeXp
    scriptRE  : /(?:<script.*?>)((\n|\r|.)*?)(?:<\/script>)/gi
    ,
    /*
     * Write(replacing) string content into the IFrames document structure
     * @param {String} content The new content
     * @param {Boolean} loadScripts (optional) true to also render and process embedded scripts
     * @param {Function} callback (optional) Callback when update is complete.
     */
    update : function(content,loadScripts,callback){

        loadScripts = loadScripts || this.getUpdateManager().loadScripts || false;

        content = Ext.DomHelper.markup(content||'');
        content = loadScripts===true ? content:content.replace(this.scriptRE , "");

        var doc;

        if(doc = this.getDocument()){

            this._frameAction = !!content.length;

            this._windowContext = this.src = null;
            this._callBack = callback || false;
            this._unHook();
            this.showMask();
            doc.open();
            doc.write(content);
            doc.close();
            this.frameInit= true; //control initial event chatter
            if(this._frameAction){
                this.checkDOM();
            } else {
                this.hideMask(true);
                if(this._callBack)this._callBack();
            }

        }else{
            this.hideMask(true);
            if(this._callBack)this._callBack();
        }
        return this;
    },

    /* Enables/disables x-frame messaging interface */
    disableMessaging :  true,

    //Private, frame messaging interface (for same-domain-policy frames only)
    _XFrameMessaging  :  function(){
        //each tag gets a hash queue ($ = no tag ).
        var tagStack = {'$' : [] };
        var isEmpty = function(v, allowBlank){
             return v === null || v === undefined || (!allowBlank ? v === '' : false);
        };
        window.sendMessage = function(message, tag, origin ){
            var MIF;
            if(MIF = arguments.callee.manager){
                if(message._fromHost){
                    var fn, result;
                    //only raise matching-tag handlers
                    var compTag= message.tag || tag || null;
                    var mstack = !isEmpty(compTag)? tagStack[compTag.toLowerCase()]||[] : tagStack["$"];

                    for(var i=0,l=mstack.length;i<l;i++){
                        if(fn = mstack[i]){
                            result = fn.apply(fn.__scope,arguments)===false?false:result;
                            if(fn.__single){mstack[i] = null;}
                            if(result === false){break;}
                        }
                    }

                    return result;
                }else{

                    message =
                        {type   :isEmpty(tag)?'message':'message:'+tag.toLowerCase().replace(/^\s+|\s+$/g,'')
                        ,data   :message
                        ,domain :origin || document.domain
                        ,uri    :document.documentURI
                        ,source :window
                        ,tag    :isEmpty(tag)?null:tag.toLowerCase()
                        };

                    try{
                       return MIF.disableMessaging !== true
                        ? MIF.fireEvent.call(MIF,message.type,MIF, message)
                        : null;
                    }catch(ex){} //trap for message:tag handlers not yet defined

                    return null;
                }

            }
        };
        window.onhostmessage = function(fn,scope,single,tag){

            if(typeof fn == 'function' ){
                if(!isEmpty(fn.__index)){
                    throw "onhostmessage: duplicate handler definition" + (tag?" for tag:"+tag:'');
                }

                var k = isEmpty(tag)? "$":tag.toLowerCase();
                tagStack[k] || ( tagStack[k] = [] );
                Ext.apply(fn,{
                   __tag    : k
                  ,__single : single || false
                  ,__scope  : scope || window
                  ,__index  : tagStack[k].length
                });
                tagStack[k].push(fn);

            } else
               {throw "onhostmessage: function required";}


        };
        window.unhostmessage = function(fn){
            if(typeof fn == 'function' && typeof fn.__index != 'undefined'){
                var k = fn.__tag || "$";
                tagStack[k][fn.__index]=null;
            }
        };


    }
    ,get   :function(el){
             return  MIM.El.get(this, el);
         }

    ,fly : function(el, named){
        named = named || '_global';
        el = this.getDom(el);
        if(!el){
            return null;
        }
        if(!MIM._flyweights[named]){
            MIM._flyweights[named] = new Ext.Element.Flyweight();
        }
        MIM._flyweights[named].dom = el;
        return MIM._flyweights[named];
    }

    ,getDom  : function(el){
         var d;
         if(!el || !(d = this.getDocument())){
            return null;
         }
         return el.dom ? el.dom : (typeof el == 'string' ? d.getElementById(el) : el);

    }
    /**
     * Creates a {@link Ext.CompositeElement} for child nodes based on the passed CSS selector (the selector should not contain an id).
     * @param {String} selector The CSS selector
     * @param {Boolean} unique (optional) True to create a unique Ext.Element for each child (defaults to false, which creates a single shared flyweight object)
     * @return {CompositeElement/CompositeElementLite} The composite element
     */
    ,select : function(selector, unique){
        var d;
        return (d = this.getDocument())?Ext.Element.select(selector, unique, d):null;
     }

    /**
     * Selects frame document child nodes based on the passed CSS selector (the selector should not contain an id).
     * @param {String} selector The CSS selector
     * @return {Array} An array of the matched nodes
     */
    ,query : function(selector){
        var d;
        return (d = this.getDocument())?Ext.DomQuery.select(selector, d):null;
     }


    /**
     * Returns the current HTML document object as an {@link Ext.Element}.
     * @return Ext.Element The document
    */
    ,getDoc  : function(){
        return this.get(this.getDocument());
    }

    /**
     * Removes a DOM Element from the embedded documents
     * @param {Element, String} node The node id or node Element to remove

     */
    ,removeNode  : function(node){
        MIM.removeNode(this,this.getDom(node));
    }

    //Private : clear all event listeners and Element cache
    ,_unHook     : function(){

        var elcache, h = MIM.getFrameHash(this)||{};

        if( this._hooked && h && (elcache = h.elCache)){

            for (var id in elcache){
                var el = elcache[id];

                delete elcache[id];
                if(el.removeAllListeners)el.removeAllListeners();
            }
            if(h.docEl){
                h.docEl.removeAllListeners();
                h.docEl=null;
                delete h.docEl;
            }
        }
        this._hooked = this._domReady = this._domFired = false;

    }
    //Private execScript sandbox and messaging interface
    ,_renderHook : function(){

        this._windowContext = this.CSS = null;
        this._hooked = false;
        try{
           if(this.writeScript('(function(){(window.hostMIF = parent.Ext.get("'+
                                this.dom.id+
                                '"))._windowContext='+
                                (Ext.isIE?'window':'{eval:function(s){return eval(s);}}')+
                                ';})();')
                ){
                this._frameProxy || (this._frameProxy = MIM.eventProxy.createDelegate(this));
                var w= this.getWindow();
                EV.doAdd(w, 'focus', this._frameProxy);
                EV.doAdd(w, 'blur',  this._frameProxy);
                EV.doAdd(w, 'unload', this._frameProxy );

                if(this.disableMessaging !== true){
                   this.loadFunction({name:'XMessage',fn:this._XFrameMessaging},false,true);
                   var sm;
                   if(sm = w.sendMessage){
                       sm.manager = this;
                   }
                }
                this.CSS = new CSSInterface(this.getDocument());

           }

          }catch(ex){}

        return this.domWritable();

    },
    /* dispatch a message to the embedded frame-window context */
    sendMessage : function (message,tag,origin){
         var win;
         if(this.disableMessaging !== true && (win = this.getWindow())){
              //support frame-to-frame messaging relay
              tag || (tag= message.tag || '');
              tag = tag.toLowerCase();
              message = Ext.applyIf(message.data?message:{data:message},
                                 {type   :Ext.isEmpty(tag)?'message':'message:'+tag
                                 ,domain :origin || document.domain
                                 ,uri    : document.documentURI
                                 ,source : window
                                 ,tag    :tag || null
                                 ,_fromHost: this
                    });
             return win.sendMessage?win.sendMessage.call(null,message,tag,origin): null;
         }
         return null;

    },
    _windowContext : null,
    /*
      Return the Iframes document object
    */
    getDocument:function(){
      var win=this.getWindow(), doc=null;
      try{
        doc = (Ext.isIE && win?win.document : null ) ||
              this.dom.contentDocument ||
              window.frames[this.id].document ||
              null;
      }catch(gdEx){
        return false;  //signifies probable access restriction
        }
      return doc;
    },

    //Attempt to retrieve the frames current document.body
    getBody : function(){
        var d;
        return (d = this.getDocument())?d.body:null;
    },

    //Attempt to retrieve the frames current URI
    getDocumentURI : function(){
        var URI, d;
        try{
           URI = this.src && (d = this.getDocument()) ? d.location.href:null;
        }catch(ex){} //will fail on NON-same-origin domains
        return URI || this.src; //fallback to last known
    },
    /*
     Return the Iframes window object
    */
    getWindow:function(){
        var dom= this.dom, win=null;
        try{
            win = dom.contentWindow||window.frames[dom.name]||null;
        }catch(gwEx){}
        return win;
    },

    /*
     Print the contents of the Iframes (if we own the document)
    */
    print:function(){
        try{
            var win = this.getWindow();
            if(Ext.isIE){win.focus();}
            win.print();
        } catch(ex){
            throw 'print exception: ' + (ex.description || ex.message || ex);
        }
    },
    //private
    destroy:function(){
        this.removeAllListeners();

        if(this.dom){
             //unHook the Iframes loaded state handlers
             this.dom[this._eventName]=null;

             Ext.ux.ManagedIFrame.Manager.deRegister(this);
             this._windowContext = null;
             //IE Iframe cleanup
             if(Ext.isIE && this.dom.src){
                this.dom.src = 'javascript:false';
             }
             this._maskEl = null;
             this.remove();
        }

        if(this.loadMask){ Ext.apply(this.loadMask,{masker :null ,maskEl : null});}

    }
    /* Returns the general DOM modification capability of the frame. */
    ,domWritable  : function(){
        return !!this._windowContext;
    }
    /*
     *  eval a javascript code block(string) within the context of the Iframes window object.
     * @param {String} block A valid ('eval'able) script source block.
     * @param {Boolean} useDOM - if true inserts the fn into a dynamic script tag,
     *                           false does a simple eval on the function definition. (useful for debugging)
     * <p> Note: will only work after a successful iframe.(Updater) update
     *      or after same-domain document has been hooked, otherwise an exception is raised.
     */
    ,execScript: function(block, useDOM){
      try{
        if(this.domWritable()){
            if(useDOM){
               this.writeScript(block);
            }else{
                return this._windowContext.eval(block);
            }

        }else{ throw 'execScript:non-secure context' }
       }catch(ex){
            this.fireEvent('exception', this, ex);
            return false;
        }
        return true;

    }
    /*
     *  write a <script> block into the iframe's document
     * @param {String} block A valid (executable) script source block.
     * @param {object} attributes Additional Script tag attributes to apply to the script Element (for other language specs [vbscript, Javascript] etc.)
     * <p> Note: writeScript will only work after a successful iframe.(Updater) update
     *      or after same-domain document has been hooked, otherwise an exception is raised.
     */
    ,writeScript  : function(block, attributes) {
        attributes = Ext.apply({},attributes||{},{type :"text/javascript",text:block});

         try{
            var head,script, doc= this.getDocument();
            if(doc && typeof doc.getElementsByTagName != 'undefined'){
                if(!(head = doc.getElementsByTagName("head")[0] )){
                    //some browsers (Webkit, Safari) do not auto-create
                    //head elements during document.write
                    head =doc.createElement("head");
                    doc.getElementsByTagName("html")[0].appendChild(head);
                }
                if(head && (script = doc.createElement("script"))){
                    for(var attrib in attributes){
                          if(attributes.hasOwnProperty(attrib) && attrib in script){
                              script[attrib] = attributes[attrib];
                          }
                    }
                    return !!head.appendChild(script);
                }
            }
         }catch(ex){
             //console.warn('writeScript Exception ', ex);
             this.fireEvent('exception', this, ex);}
         return false;
    }
    /*
     * Eval a function definition into the iframe window context.
     * args:
     * @param {String/Object} name of the function or
                              function map object: {name:'encodeHTML',fn:Ext.util.Format.htmlEncode}
     * @param {Boolean} useDOM - if true inserts the fn into a dynamic script tag,
                                    false does a simple eval on the function definition,
     * examples:
     * var trim = function(s){
     *     return s.replace( /^\s+|\s+$/g,'');
     *     };
     * iframe.loadFunction('trim');
     * iframe.loadFunction({name:'myTrim',fn:String.prototype.trim || trim});
     */
    ,loadFunction : function(fn, useDOM, invokeIt){

       var name  =  fn.name || fn;
       var    fn =  fn.fn   || window[fn];
       this.execScript(name + '=' + fn, useDOM); //fn.toString coercion
       if(invokeIt){
           this.execScript(name+'()') ; //no args only
        }
    }

    //Private
    ,showMask: function(msg,msgCls,forced){
          var lmask;
          if((lmask = this.loadMask) && (!lmask.disabled|| forced)){
               if(lmask._vis)return;
               lmask.masker || (lmask.masker = Ext.get(lmask.maskEl||this.dom.parentNode||this.wrap({tag:'div',style:{position:'relative'}})));
               lmask._vis = true;
               lmask.masker.mask.defer(lmask.delay||5,lmask.masker,[msg||lmask.msg , msgCls||lmask.msgCls] );
           }
       }
    //Private
    ,hideMask: function(forced){
           var tlm;
           if((tlm = this.loadMask) && !tlm.disabled && tlm.masker ){
               if(!forced && (tlm.hideOnReady!==true && this._domReady)){return;}
               tlm._vis = false;
               tlm.masker.unmask.defer(tlm.delay||5,tlm.masker);
           }
    }

    /* Private
      Evaluate the Iframes readyState/load event to determine its 'load' state,
      and raise the 'domready/documentloaded' event when applicable.
    */
    ,loadHandler : function(e,target){

        if(!this.frameInit  || (!this._frameAction && !this.eventsFollowFrameLinks)){return;}
        target || (target={});
        var rstatus = (e && typeof e.type !== 'undefined'?e.type:this.dom.readyState );
        switch(rstatus){
            case 'loading':  //IE
            case 'interactive': //IE
              break;
            case 'domready': //MIF
              if(this._domReady)return;
              this._domReady = true;
              if( this._hooked = this._renderHook() ){ //Only raise if sandBox injection succeeded (same domain)
                 this._domFired = true;
                 this.fireEvent("domready",this);
              }
            case 'domfail': //MIF
              this._domReady = true;
              this.hideMask();
              break;
            case 'load': //Gecko, Opera
            case 'complete': //IE
              if(!this._domReady ){  // one last try for slow DOMS.
                  this.loadHandler({type:'domready',id:this.id});
              }
              this.hideMask(true);
              if(this._frameAction || this.eventsFollowFrameLinks ){

                //not going to wait for the event chain, as it's not cancellable anyhow.
                this.fireEvent.defer(50,this,["documentloaded",this]);
              }
              this._frameAction = this._frameInit = false;

              if(this.eventsFollowFrameLinks){  //reset for link tracking
                  this._domFired = this._domReady = false;
              }
              if(this._callBack){
                   this._callBack(this);
              }

              break;
            default:
        }

        this.frameState = rstatus;

    }
    /* Private
      Poll the Iframes document structure to determine DOM ready state,
      and raise the 'domready' event when applicable.
    */
    ,checkDOM : function(win){
        if(Ext.isOpera || Ext.isGecko || !this._frameAction )return;
        //initialise the counter
        var n = 0
            ,win = win||this.getWindow()
            ,manager = this
            ,domReady = false
            ,max = 300;

            var poll =  function(){  //DOM polling for IE and others
               try{

                 var doc = manager.getDocument(),body=null;
                 if(doc ===false){throw "Document Access Denied"; }

                 if(!manager._domReady){
                    domReady = !!(doc && doc.getElementsByTagName);
                    domReady = domReady && (body = doc.getElementsByTagName('body')[0]) && !!body.innerHTML.length;
                 }

               }catch(ex){
                     n = max; //likely same-origin policy violation, so DOM is ready
               }

                //if the timer has reached 100 (timeout after 3 seconds)
                //in practice, shouldn't take longer than 7 iterations [in kde 3
                //in second place was IE6, which takes 2 or 3 iterations roughly 5% of the time]

                if(!manager._frameAction || manager._domReady)return;

                if((++n < max) && !domReady )
                {
                    //try again
                    setTimeout(arguments.callee, 10);
                    return;
                }

                manager.loadHandler ({type:domReady?'domready':'domfail'});

            };
            setTimeout(poll,40);
     }
 });

/* Stylesheet Frame interface object */
var styleCamelRe = /(-[a-z])/gi;
var styleCamelFn = function(m, a){ return a.charAt(1).toUpperCase(); };
var CSSInterface = function(hostDocument){
    var doc;
    if(hostDocument){

        doc = hostDocument;

    return {
        rules : null,
       /**
        * Creates a stylesheet from a text blob of rules.
        * These rules will be wrapped in a STYLE tag and appended to the HEAD of the document.
        * @param {String} cssText The text containing the css rules
        * @param {String} id An id to add to the stylesheet for later removal
        * @return {StyleSheet}
        */
       createStyleSheet : function(cssText, id){
           var ss;

           if(!doc)return;
           var head = doc.getElementsByTagName("head")[0];
           var rules = doc.createElement("style");
           rules.setAttribute("type", "text/css");
           if(id){
               rules.setAttribute("id", id);
           }
           if(Ext.isIE){
               head.appendChild(rules);
               ss = rules.styleSheet;
               ss.cssText = cssText;
           }else{
               try{
                    rules.appendChild(doc.createTextNode(cssText));
               }catch(e){
                   rules.cssText = cssText;
               }
               head.appendChild(rules);
               ss = rules.styleSheet ? rules.styleSheet : (rules.sheet || doc.styleSheets[doc.styleSheets.length-1]);
           }
           this.cacheStyleSheet(ss);
           return ss;
       },

       /**
        * Removes a style or link tag by id
        * @param {String} id The id of the tag
        */
       removeStyleSheet : function(id){

           if(!doc)return;
           var existing = doc.getElementById(id);
           if(existing){
               existing.parentNode.removeChild(existing);
           }
       },

       /**
        * Dynamically swaps an existing stylesheet reference for a new one
        * @param {String} id The id of an existing link tag to remove
        * @param {String} url The href of the new stylesheet to include
        */
       swapStyleSheet : function(id, url){
           this.removeStyleSheet(id);

           if(!doc)return;
           var ss = doc.createElement("link");
           ss.setAttribute("rel", "stylesheet");
           ss.setAttribute("type", "text/css");
           ss.setAttribute("id", id);
           ss.setAttribute("href", url);
           doc.getElementsByTagName("head")[0].appendChild(ss);
       },

       /**
        * Refresh the rule cache if you have dynamically added stylesheets
        * @return {Object} An object (hash) of rules indexed by selector
        */
       refreshCache : function(){
           return this.getRules(true);
       },

       // private
       cacheStyleSheet : function(ss){
           if(this.rules){
               this.rules = {};
           }
           try{// try catch for cross domain access issue
               var ssRules = ss.cssRules || ss.rules;
               for(var j = ssRules.length-1; j >= 0; --j){
                   this.rules[ssRules[j].selectorText] = ssRules[j];
               }
           }catch(e){}
       },

       /**
        * Gets all css rules for the document
        * @param {Boolean} refreshCache true to refresh the internal cache
        * @return {Object} An object (hash) of rules indexed by selector
        */
       getRules : function(refreshCache){
            if(this.rules == null || refreshCache){
                this.rules = {};

                if(doc){
                    var ds = doc.styleSheets;
                    for(var i =0, len = ds.length; i < len; i++){
                        try{
                            this.cacheStyleSheet(ds[i]);
                        }catch(e){}
                    }
                }
            }
            return this.rules;
        },

        /**
        * Gets an an individual CSS rule by selector(s)
        * @param {String/Array} selector The CSS selector or an array of selectors to try. The first selector that is found is returned.
        * @param {Boolean} refreshCache true to refresh the internal cache if you have recently updated any rules or added styles dynamically
        * @return {CSSRule} The CSS rule or null if one is not found
        */
       getRule : function(selector, refreshCache){
            var rs = this.getRules(refreshCache);
            if(!Ext.isArray(selector)){
                return rs[selector];
            }
            for(var i = 0; i < selector.length; i++){
                if(rs[selector[i]]){
                    return rs[selector[i]];
                }
            }
            return null;
        },

        /**
        * Updates a rule property
        * @param {String/Array} selector If it's an array it tries each selector until it finds one. Stops immediately once one is found.
        * @param {String} property The css property
        * @param {String} value The new value for the property
        * @return {Boolean} true If a rule was found and updated
        */
       updateRule : function(selector, property, value){
            if(!Ext.isArray(selector)){
                var rule = this.getRule(selector);
                if(rule){
                    rule.style[property.replace(styleCamelRe, styleCamelFn)] = value;
                    return true;
                }
            }else{
                for(var i = 0; i < selector.length; i++){
                    if(this.updateRule(selector[i], property, value)){
                        return true;
                    }
                }
            }
            return false;
        }
    };}
};

 /*
  * @class Ext.ux.ManagedIFramePanel
  * Version:  1.2  (8/22/2008)


  * Author: Doug Hendricks - doug[always-At]theactivegroup.com
  *
  *
 */
 Ext.ux.ManagedIframePanel = Ext.extend(Ext.Panel, {

    /**
    * Cached Iframe.src url to use for refreshes. Overwritten every time setSrc() is called unless "discardUrl" param is set to true.
    * @type String/Function (which will return a string URL when invoked)
     */
    defaultSrc  :null,
    bodyStyle   :{height:'100%',width:'100%', position:'relative'},

    /**
    * @cfg {String/Object} frameStyle
    * Custom CSS styles to be applied to the ux.ManagedIframe element in the format expected by {@link Ext.Element#applyStyles}
    * (defaults to CSS Rule {overflow:'auto'}).
    */
    frameStyle  : {overflow:'auto'},
    frameConfig : null,
    hideMode    : !Ext.isIE?'nosize':'display',
    shimCls     : Ext.ux.ManagedIFrame.Manager.shimCls,
    shimUrl     : null,
    loadMask    : false,
    stateful    : false,
    animCollapse: Ext.isIE && Ext.enableFx,
    autoScroll  : false,
    closable    : true, /* set True by default in the event a site times-out while loadMasked */
    ctype       : "Ext.ux.ManagedIframePanel",
    showLoadIndicator : false,

    /**
    *@cfg {String/Object} unsupportedText Text (or Ext.DOMHelper config) to display within the rendered iframe tag to indicate the frame is not supported
    */
    unsupportedText : 'Inline frames are NOT enabled\/supported by your browser.'

   ,initComponent : function(){

        this.bodyCfg ||
           (this.bodyCfg =
                  {  cls    :'x-managed-iframe-mask' //shared masking DIV for hosting loadMask/dragMask
                    ,children:[
                        //Ext.apply(
                          Ext.apply({
                              tag          :'iframe',
                              frameborder  : 0,
                              cls          : 'x-managed-iframe',
                              style        : this.frameStyle || null,
                              html         :this.unsupportedText||null
                            },this.frameConfig?this.frameConfig.autoCreate||{}:false
                            , Ext.isIE && Ext.isSecure?{src:Ext.SSL_SECURE_URL}:false
                            )
                             //the shimming agent
                            ,{tag:'img', src:this.shimUrl||Ext.BLANK_IMAGE_URL , cls: this.shimCls , galleryimg:"no"}
                         ]
           });

         this.autoScroll = false; //Force off as the Iframe manages this
         this.items = null;

         //setup stateful events if not defined
         if(this.stateful !== false){
             this.stateEvents || (this.stateEvents = ['documentloaded']);
         }

         Ext.ux.ManagedIframePanel.superclass.initComponent.call(this);

         this.monitorResize || (this.monitorResize = this.fitToParent);

         this.addEvents({documentloaded:true, domready:true,message:true,exception:true});

         //apply the addListener patch for 'message:tagging'
         this.addListener = this.on;

    },

    doLayout   :  function(){
        //only resize (to Parent) if the panel is NOT in a layout.
        //parentNode should have {style:overflow:hidden;} applied.
        if(this.fitToParent && !this.ownerCt){
            var pos = this.getPosition(), size = (Ext.get(this.fitToParent)|| this.getEl().parent()).getViewSize();
            this.setSize(size.width - pos[0], size.height - pos[1]);
        }
        Ext.ux.ManagedIframePanel.superclass.doLayout.apply(this,arguments);

    },

      // private
    beforeDestroy : function(){

        if(this.rendered){

             if(this.tools){
                for(var k in this.tools){
                      Ext.destroy(this.tools[k]);
                }
             }

             if(this.header && this.headerAsText){
                var s;
                if( s=this.header.child('span')) s.remove();
                this.header.update('');
             }

             Ext.each(['iframe','shim','header','topToolbar','bottomToolbar','footer','loadMask','body','bwrap'],
                function(elName){
                  if(this[elName]){
                    if(typeof this[elName].destroy == 'function'){
                         this[elName].destroy();
                    } else { Ext.destroy(this[elName]); }

                    this[elName] = null;
                    delete this[elName];
                  }
             },this);
        }

        Ext.ux.ManagedIframePanel.superclass.beforeDestroy.call(this);
    },
    onDestroy : function(){
        //Yes, Panel.super (Component), since we're doing Panel cleanup beforeDestroy instead.
        Ext.Panel.superclass.onDestroy.call(this);
    },
    // private
    onRender : function(ct, position){
        Ext.ux.ManagedIframePanel.superclass.onRender.call(this, ct, position);

        if(this.iframe = this.body.child('iframe.x-managed-iframe')){
            this.iframe.ownerCt = this;

            // Set the Visibility Mode for el, bwrap for collapse/expands/hide/show
            var El = Ext.Element;
            var mode = El[this.hideMode.toUpperCase()] || 'x-hide-nosize';
            Ext.each(
                [this[this.collapseEl],this.floating? null: this.getActionEl(),this.iframe]
                ,function(el){
                     if(el)el.setVisibilityMode(mode);
            },this);

            if(this.loadMask){
                this.loadMask = Ext.apply({disabled     :false
                                          ,maskEl       :this.body
                                          ,hideOnReady  :true}
                                          ,this.loadMask);
             }

            if(this.iframe = new Ext.ux.ManagedIFrame(this.iframe, {
                    loadMask           :this.loadMask
                   ,showLoadIndicator  :this.showLoadIndicator
                   ,disableMessaging   :this.disableMessaging
                   ,style              :this.frameStyle
                   })){

                this.loadMask = this.iframe.loadMask;

                this.relayEvents(this.iframe, ["blur", "focus", "unload", "documentloaded","domready","exception","message"].concat(this._msgTagHandlers ||[]));
                delete this._msgTagHandlers;
            }

            this.getUpdater().showLoadIndicator = this.showLoadIndicator || false;

            // Enable auto-dragMask if the panel participates in (nested?) border layout.
            // Setup event handlers on the SplitBars to enable the frame dragMask when needed
            var ownerCt = this.ownerCt;
            while(ownerCt){

                ownerCt.on('afterlayout',function(container,layout){
                        var MIM = Ext.ux.ManagedIFrame.Manager,st=false;
                        Ext.each(['north','south','east','west'],function(region){
                            var reg;
                            if((reg = layout[region]) && reg.splitEl){
                                st = true;
                                if(!reg.split._splitTrapped){
                                    reg.split.on('beforeresize',MIM.showShims,MIM);
                                    reg.split._splitTrapped = true;
                                }
                            }
                        },this);
                        if(st && !this._splitTrapped ){
                            this.on('resize',MIM.hideShims,MIM);
                            this._splitTrapped = true;

                        }

                },this,{single:true}); //and discard

                ownerCt = ownerCt.ownerCt; //nested layouts?
             }


        }
        this.shim = Ext.get(this.body.child('.'+this.shimCls));
    },

    /* Toggles the built-in MIF shim */
    toggleShim   : function(){

        if(this.shim && this.shimCls)this.shim.toggleClass(this.shimCls+'-on');
    },
        // private
    afterRender : function(container){
        var html = this.html;
        delete this.html;
        Ext.ux.ManagedIframePanel.superclass.afterRender.call(this);
        if(this.iframe){
            if(this.defaultSrc){
                this.setSrc();
            }
            else if(html){
                this.iframe.update(typeof html == 'object' ? Ext.DomHelper.markup(html) : html);
            }
        }
    }
    ,sendMessage :function (){
        if(this.iframe){
            this.iframe.sendMessage.apply(this.iframe,arguments);
        }
    }
    //relay all defined 'message:tag' event handlers
    ,on : function(name){
           var tagRE=/^message\:/i, n = null;
           if(typeof name == 'object'){
               for (var na in name){
                   if(!this.filterOptRe.test(na) && tagRE.test(na)){
                      n || (n=[]);
                      n.push(na.toLowerCase());
                   }
               }
           } else if(tagRE.test(name)){
                  n=[name.toLowerCase()];
           }

           if(this.getFrame() && n){
               this.relayEvents(this.iframe,n);
           }else{
               this._msgTagHandlers || (this._msgTagHandlers =[]);
               if(n)this._msgTagHandlers = this._msgTagHandlers.concat(n); //queued for onRender when iframe is available
           }
           Ext.ux.ManagedIframePanel.superclass.on.apply(this, arguments);
    },
    /**
    * Sets the embedded Iframe src property.
    * @param {String/Function} url (Optional) A string or reference to a Function that returns a URI string when called
    * @param {Boolean} discardUrl (Optional) If not passed as <tt>false</tt> the URL of this action becomes the default URL for
    * this panel, and will be subsequently used in future setSrc calls.
    * Note:  invoke the function with no arguments to refresh the iframe based on the current defaultSrc value.
    */
    setSrc : function(url, discardUrl,callback){
         url = url || this.defaultSrc || false;

         if(!url)return this;

         if(url.url){
            callback = url.callback || false;
            discardUrl = url.discardUrl || false;
            url = url.url || false;

         }
         var src = url || (Ext.isIE&&Ext.isSecure?Ext.SSL_SECURE_URL:'');

         if(this.rendered && this.iframe){
              this.iframe.setSrc(src,discardUrl,callback);
           }

         return this;
    },

    //Make it state-aware
    getState: function(){

         var URI = this.iframe?this.iframe.getDocumentURI()||null:null;
         return Ext.apply(Ext.ux.ManagedIframePanel.superclass.getState.call(this) || {},
             URI?{defaultSrc  : typeof URI == 'function'?URI():URI}:null );

    },
    /**
     * Get the {@link Ext.Updater} for this panel's iframe/or body. Enables you to perform Ajax-based document replacement of this panel's iframe document.
     * @return {Ext.Updater} The Updater
     */
    getUpdater : function(){
        return this.rendered?(this.iframe||this.body).getUpdater():null;
    },
    /**
     * Get the embedded iframe Ext.Element for this panel
     * @return {Ext.Element} The Panels ux.ManagedIFrame instance.
     */
    getFrame : function(){
        return this.rendered?this.iframe:null
    },
    /**
     * Get the embedded iframe's window object
     * @return {Object} or Null if unavailable
     */
    getFrameWindow : function(){
        return this.rendered && this.iframe?this.iframe.getWindow():null;
    },
    /**
     * Get the embedded iframe's document object
     * @return {Element} or null if unavailable
     */
    getFrameDocument : function(){
        return this.rendered && this.iframe?this.iframe.getDocument():null;
    },

    /**
     * Get the embedded iframe's document as an Ext.Element.
     * @return {Ext.Element object} or null if unavailable
     */
    getFrameDoc : function(){
        return this.rendered && this.iframe?this.iframe.getDoc():null;
    },

    /**
     * Get the embedded iframe's document.body Element.
     * @return {Element object} or null if unavailable
     */
    getFrameBody : function(){
        return this.rendered && this.iframe?this.iframe.getBody():null;
    },
     /**
      * Loads this panel's iframe immediately with content returned from an XHR call.
      * @param {Object/String/Function} config A config object containing any of the following options:
    <pre><code>
    panel.load({
        url: "your-url.php",
        params: {param1: "foo", param2: "bar"}, // or a URL encoded string
        callback: yourFunction,
        scope: yourObject, // optional scope for the callback
        discardUrl: false,
        nocache: false,
        text: "Loading...",
        timeout: 30,
        scripts: false,
        renderer:{render:function(el, response, updater, callback){....}}  //optional custom renderer
    });
    </code></pre>
         * The only required property is url. The optional properties nocache, text and scripts
         * are shorthand for disableCaching, indicatorText and loadScripts and are used to set their
         * associated property on this panel Updater instance.
         * @return {Ext.Panel} this
         */
    load : function(loadCfg){
         var um;
         if(um = this.getUpdater()){
            if (loadCfg && loadCfg.renderer) {
                 um.setRenderer(loadCfg.renderer);
                 delete loadCfg.renderer;
            }
            um.update.apply(um, arguments);
         }
         return this;
    }
     // private
    ,doAutoLoad : function(){
        this.load(
            typeof this.autoLoad == 'object' ?
                this.autoLoad : {url: this.autoLoad});
    }

});

Ext.reg('iframepanel', Ext.ux.ManagedIframePanel);

Ext.ux.ManagedIframePortlet = Ext.extend(Ext.ux.ManagedIframePanel, {
     anchor: '100%',
     frame:true,
     collapseEl:'bwrap',
     collapsible:true,
     draggable:true,
     cls:'x-portlet'
 });
Ext.reg('iframeportlet', Ext.ux.ManagedIframePortlet);

/* override adds a third visibility feature to Ext.Element:
* Now an elements' visibility may be handled by application of a custom (hiding) CSS className.
* The class is removed to make the Element visible again
*/

Ext.apply(Ext.Element.prototype, {
  setVisible : function(visible, animate){
        if(!animate || !Ext.lib.Anim){
            if(this.visibilityMode == Ext.Element.DISPLAY){
                this.setDisplayed(visible);
            }else if(this.visibilityMode == Ext.Element.VISIBILITY){
                this.fixDisplay();
                this.dom.style.visibility = visible ? "visible" : "hidden";
            }else {
                this[visible?'removeClass':'addClass'](String(this.visibilityMode));
            }

        }else{
            // closure for composites
            var dom = this.dom;
            var visMode = this.visibilityMode;

            if(visible){
                this.setOpacity(.01);
                this.setVisible(true);
            }
            this.anim({opacity: { to: (visible?1:0) }},
                  this.preanim(arguments, 1),
                  null, .35, 'easeIn', function(){

                     if(!visible){
                         if(visMode == Ext.Element.DISPLAY){
                             dom.style.display = "none";
                         }else if(visMode == Ext.Element.VISIBILITY){
                             dom.style.visibility = "hidden";
                         }else {
                             Ext.get(dom).addClass(String(visMode));
                         }
                         Ext.get(dom).setOpacity(1);
                     }
                 });
        }
        return this;
    },
    /**
     * Checks whether the element is currently visible using both visibility and display properties.
     * @param {Boolean} deep (optional) True to walk the dom and see if parent elements are hidden (defaults to false)
     * @return {Boolean} True if the element is currently visible, else false
     */
    isVisible : function(deep) {
        var vis = !(this.getStyle("visibility") == "hidden" || this.getStyle("display") == "none" || this.hasClass(this.visibilityMode));
        if(deep !== true || !vis){
            return vis;
        }
        var p = this.dom.parentNode;
        while(p && p.tagName.toLowerCase() != "body"){
            if(!Ext.fly(p, '_isVisible').isVisible()){
                return false;
            }
            p = p.parentNode;
        }
        return true;
    }
});

Ext.onReady( function(){
  //Generate CSS Rules but allow for overrides.
    var CSS = Ext.util.CSS, rules=[];

    CSS.getRule('.x-managed-iframe') || ( rules.push('.x-managed-iframe {height:100%;width:100%;overflow:auto;}'));
    CSS.getRule('.x-managed-iframe-mask')||(rules.push('.x-managed-iframe-mask{width:100%;height:100%;position:relative;}'));
    if(!CSS.getRule('.x-frame-shim')){
        rules.push('.x-frame-shim {z-index:8500;position:absolute;top:0px;left:0px;background:transparent!important;overflow:hidden;display:none;}');
        rules.push('.x-frame-shim-on{width:100%;height:100%;display:block;zoom:1;}');
        rules.push('.ext-ie6 .x-frame-shim{margin-left:5px;margin-top:3px;}');
    }
    CSS.getRule('.x-hide-nosize') || (rules.push('.x-hide-nosize,.x-hide-nosize *{height:0px!important;width:0px!important;border:none;}'));

    if(!!rules.length){
        CSS.createStyleSheet(rules.join(' '));
    }
});
})();
//@ sourceURL=<miframe.js>