/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/
CKEDITOR.skins.add("office2003",function(){return{editor:{css:["editor.css"]},dialog:{css:["dialog.css"]},separator:{canGroup:!1},templates:{css:["templates.css"]},margins:[0,14,18,14]}}()),function(){function e(){CKEDITOR.dialog.on("resize",function(e){var t=e.data,i=t.width,n=t.height,a=t.dialog,o=a.parts.contents;if("office2003"==t.skin&&(o.setStyles({width:i+"px",height:n+"px"}),CKEDITOR.env.ie&&!CKEDITOR.env.ie9Compat)){var r=function(){var e=a.parts.dialog.getChild([0,0,0]),t=e.getChild(0),i=t.getSize("width");n+=t.getChild(0).getSize("height")+1;var o=e.getChild(2);o.setSize("width",i),o=e.getChild(7),o.setSize("width",i-28),o=e.getChild(4),o.setSize("height",n),o=e.getChild(5),o.setSize("height",n)};setTimeout(r,100),"rtl"==e.editor.lang.dir&&setTimeout(r,1e3)}})}CKEDITOR.dialog?e():CKEDITOR.on("dialogPluginReady",e)}();