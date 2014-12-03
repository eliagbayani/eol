$(document).ready(function(){$("#taxon_name_id").bind("keyup change input",function(){$.ajax({url:"/data_search/update_attributes",dataType:"script"})})}),function(e){"function"!=typeof String.prototype.trim&&(String.prototype.trim=function(){return this.replace(/^\s+|\s+$/g,"")}),e.fn.fadeInline=function(t){var i={duration:200,display:"inline-block"},n=e.extend(i,t);return this.each(function(){e(this).css({opacity:0,display:n.display}).fadeTo(n.duration,1)})},e.fn.summarizeInput=function(t){var i={truncate:0,panel:e(this),container:e("<p/>",{"class":"summarize_input"}),wrapper:e("<span/>"),exclude:{}},n=e.extend(i,t);return this.each(function(){var t=e(this).find("label"),i=e(this).find(":input"),s=[];if(output="",i.each(function(){var i=this.name,o=e.grep(t,function(t){return e(t).attr("for")==i})[0],a="select-one"==this.type?e(this.selectedOptions).text():this.value,r="undefined"!=typeof n.exclude[i]&&(0===n.exclude[i].length||0===e.inArray(this.value,n.exclude[i]));a&&!r&&s.push([e(o).text(),n.truncate>0&&a.length>n.truncate?a.substr(0,n.truncate)+"…":a])}),s.length>0){for(var o in s)s[o]=s[o].join(": ");n.wrapper.text(s.join("; ")).appendTo(n.container),n.container.hide().appendTo(n.panel).fadeIn(500)}})},e(function(){!function(t){function i(){for(var e in o)o[e].is(":disabled")?o[e].attr("placeholder")!=r[e]&&o[e].attr("placeholder",r[e]):o[e].attr("placeholder")!=o[e].data("placeholder")&&o[e].attr("placeholder",o[e].data("placeholder"))}function n(e){e.stopImmediatePropagation(),o.min.prop("disabled",o.q.val().trim()),o.max.prop("disabled",o.q.val().trim()),a.prop("disabled",o.q.val().trim()),o.q.prop("disabled",o.min.val().trim()||o.max.val().trim()),o.min.is(":disabled")&&o.max.is(":disabled")&&o.q.is(":disabled")&&o.q(":disabled",!1),i()}var s=t.find(".vital"),o={q:t.find('input[name="q"]'),min:t.find('input[name="min"]'),max:t.find('input[name="max"]')},a=t.find('select[name="unit"]'),r={q:o.q.data("disabled-placeholder"),min:o.min.data("disabled-placeholder"),max:o.max.data("disabled-placeholder")},l=t.find('input[name="taxon_name"]'),c={taxonName:l.data("value-removed-placeholder")};e("<fieldset/>",{"class":"prominent_actions",html:e("<legend/>",{"class":"assistive",text:"Additional search submit"})}).append(t.find('#traitbank_search input[type="submit"]').clone().attr("title","Search now or move on to add more search criteria")).appendTo(s),"string"==typeof c.taxonName&&c.taxonName.length>0&&(l.data("placeholder",l.attr("placeholder")),l.attr("placeholder",c.taxonName),l.one("keyup input paste",function(){l.attr("placeholder",l.data("placeholder"))}));for(var u in o)o[u].data("placeholder",o[u].attr("placeholder")),o[u].on("keyup input paste",{n:u},n),o[u].keyup();if(t.data("results-total")>0){var h=t.find(".extras"),d=t.find("fieldset.actions"),p=e("<a/>",{href:"#"}),f={truncate:50,panel:s,container:e("<dl/>",{"class":"summarize_input"}).append(e("<dt/>").append(h.data("summary-intro"))),wrapper:e("<dd/>"),exclude:{sort:[]}};p.hide().appendTo(s),adjustSummarizeExclude=function(){o.min.val().trim()||o.max.val().trim()?"undefined"!=typeof f.exclude.unit&&delete f.exclude.unit:f.exclude.unit=[]},hide=function(){d.fadeOut(200),adjustSummarizeExclude(),h.slideUp(500,function(){p.fadeOut(200,function(){e(this).text(h.data("show")).fadeInline()})}).summarizeInput(f)},show=function(){h.slideDown(500,function(){p.fadeOut(200,function(){e(this).text(h.data("hide")).fadeInline()}),f.container.fadeOut(500,function(){f.wrapper.remove(),e(this).detach()})}),d.fadeIn(500)},e.each([p,f.container.find("a")],function(e,t){t.accessibleClick(function(){return h.is(":visible")?hide():show(),!1})}),hide()}}(e("#data_search")),limit_search_summaries()})}(jQuery),console.log("after jquery");var limit_search_summaries=function(){var e=$(".search_summary:has(ul.values)");if(e.find("li").length>9){e.find("li:gt(8)").slideUp(500);var t=e.find("li").length-9,i="Show "+t+" more",n=$('<a href="#">').text(i);n.on("click",function(t){t.preventDefault(),"true"===$(this).attr("data-open")?e.find("li:gt(8)").slideUp(500,function(){n.text(i),n.attr("data-open","false")}):e.find("li:gt(8)").slideDown(500,function(){n.text("Hide"),n.attr("data-open","true")})}),e.append($('<span class="more"></span>').append(n))}};
