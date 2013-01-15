var user;
var mappa;
var markers = [];
var lastreq;
var lastopen = undefined;
var firstreq = 1;
var current_data = {};

var grp_url = "http://opensourceecology.it/mappa";

function errore(msg) {
	$().toastmessage('showErrorToast', msg);
}

function inizializza_tabella(ogg) {
	$("#ordine th").each(function() {
		$(this).addClass("ui-state-default");
	});

	$("#ordine td").each(function() {
		$(this).addClass("ui-widget-content");
	});

	$("#ordine tr").hover(function() {
		$(this).children("td").addClass("ui-state-hover");
	}, function() {
		$(this).children("td").removeClass("ui-state-hover");
	});

	$("#ordine tr").click(function() {
		$(this).children("td").toggleClass("ui-state-highlight");
	});

	$("#ordine").tablesorter( {
headers: {
0: { sorter: false  },
1: { sorter: 'text' },
2: { sorter: 'text' },
3: { sorter: false  }
		}
	});
}

function inizializza_mappa() {
	var latitude = 42.000;
	var longitude = 13.000;
	var Ita = new google.maps.LatLng(latitude, longitude);

	mappa = new google.maps.Map($('#mappa')[0], {
		zoom:		6,
center:		Ita,
mapTypeId:	google.maps.MapTypeId.ROADMAP
	});

	google.maps.Map.prototype.removeMarks = function() {
		if (markers) {
			for (var i = 0; i < markers.length; i++) {
				markers[i].setMap(null);
			}
		}
	}

	user = new google.maps.Marker( {
position:	new google.maps.LatLng(latitude, longitude),
map:		mappa,
draggable:	true,
animation:	google.maps.Animation.DROP,
icon:		"metamarket/icone/you-are-here.png",
title:		"User"
	});


	google.maps.event.addListener(user, 'click', function() {
		if (lastopen != undefined)
			lastopen.close();

		lastopen = undefined;

	});

	google.maps.event.addListener(user, 'dragend', function() {
		if (firstreq == 0)
			$("#submit").click();
	});


}

function aggiorna_narratori(data, aggrs) {
	$("#tabella .riga").remove();
	mappa.removeMarks();
	$.each(data, function(aggr, dat) {
		if (aggrs.indexOf(aggr) != -1) {
			dat = filtra_distanza(dat);
			$.each(dat, function(id, info) {
				if (info.tooFar == 0) {
					var name   = $.trim(info.name);
					var addr   = $.trim(info.address);
					var lat    = $.trim(info.lat);
					var lon    = $.trim(info.long);
					var tel    = $.trim(info.tel);
					var open   = $.trim(info.opening);
					var close  = $.trim(info.closing);
					var categ  = $.trim(info.category).split(',')[0];
					var icona  = ('metamarket/icone/' + categ + '.png').toLowerCase();
					$("#tabella").append(
					    '<tr class="riga">' +
					    '<td><img class="icot" src="' + icona + '" /></td>' +
					    '<td>' + name + '</td>' +
					    '<td>' + addr + '</td>' +
					    '<td>' + tel  + '</td>' +
					    '</tr>'
					);

					var marker = new google.maps.Marker( {
position:	new google.maps.LatLng(lat, lon),
map:		mappa,
draggable:	false,
animation:	google.maps.Animation.DROP,
title:		name,
icon:		icona
					});

					google.maps.event.addListener(marker, 'click', function() {
						//var aperto = aprira(open);
//			var dist   = Math.round(calcola_distanza(lat, lon));
						if (lastopen != undefined)
							lastopen.close();

						var infowindow = new google.maps.InfoWindow( {
content: "<p><b>" + name + "</b></p>" +
							"<p>" + addr + "</p>" +
							"<p>" + tel + "</p>" +
							"<p>" + open + "</p>" +
							"<p>Lat:" + lat + "</p>" +
							"<p>Lon:" + lon + "</p>" +
							"<p><a href=\'#\' onClick=\"mappa.setCenter(new google.maps.LatLng(" + lat + "," + lon + "))\">Centra qui</a></p>" /*+
					"<p>" + dist + " kilometri da te</p>" +
					"<p>" + aperto + "</p>"*/
						});

						infowindow.open(mappa, this)
						lastopen = infowindow;
					});

					markers.push(marker);
				}
			});
		}
	})

	$("#ordine").trigger("update");
	$("#loader").hide();

}

function inizializza_categorie() {
	var base_url = grp_url + "/data/sample.xml";

	$.get(base_url, function(data) {
		var categs = $(data).find("category")

		categs.sort(function(a, b) {
			return $(a).attr('id') > $(b).attr('id') ? 1 : -1;
		});

		$("#loaderc").remove();

		categs.each(function() {
			var lim_max = 34;
			var aggr = $(this).attr('aggregatore').split(", ")[0];
			var desc = $(this).attr('id');
			var icona  = ('metamarket/icone/' + desc + '.png').toLowerCase();

			$('#categorie').append(
			    '<label>' +
			    '<img class="ico" src="' + icona + '"/>' +
			    '<input type="checkbox" id="' + aggr + '" name="' + desc + '" class="categoria"/>' +
			    '<a title="' + desc + '">' + desc + '</a>' +
			    '</label><br>'
			);
		});
	});

	$('.categoria').live('change', function() {
		$("#submit").click();
	});
}

function inizializza_ricerca() {
	// Mostra la "X" se c'è testo
	$("#field").keyup(function() {
		$("#x").fadeIn();

		if ($.trim($("#field").val()) == "") {
			$("#x").fadeOut();
		}
	});

	// Cancella il testo quando si clicca sulla X
	$("#x").click(function() {
		$("#field").val("");
		$("#field").blur();
		$(this).hide();
	});

	// Imposta testo predefinito
	$("#field").live("blur", function() {
		var default_value = $(this).attr("rel");

		if ($(this).val() == "") {
			$(this).val(default_value);
		}
	}).live("focus", function() {
		var default_value = $(this).attr("rel");

		if ($(this).val() == default_value) {
			$(this).val("");
		}
	});

	$('#field').keypress(function(e) {
		if (e.which == 13) {
			$("#submit").click();
		}
	});

	$("#field").blur();
}

function trova_locations(nome, raggio, aggrs, categs) {
	var base_url = grp_url + "/data";

	if (aggrs.length == 0) {
		aggiorna_narratori(current_data, aggrs);
		return;
	}

	if ((nome == "") || (nome == "Cerca un nome..."))
		nome = "undef";

	/*	base_url += aggrs.join('/'); + '/params/' +
	//		p.lat() + '/' + p.lng() + '/' + raggio +
	//		'/' + encodeURIComponent(categs) + '/' + nome;
	*/
	if (lastreq != undefined)
		lastreq.abort();

	lastreq = 1;
	aggrs.forEach(function(aggr) {
		if (current_data[aggr] == undefined) {
			current_data[aggr] = {};
			base_url += "/" + aggr;
			$.get(base_url, function(data) {
				data = eval('(' + data + ')');
				$.each(data.locations, function(id, info) {
					current_data[aggr][id] = info;
				})
				aggiorna_narratori(current_data, aggrs);

				firstreq = 0;
			})
		}

		lastreq = undefined;
	});
	aggiorna_narratori(current_data, aggrs);
}
//TODO
function filtra_distanza(data) {
	$.each(data, function(id, info) {
		if (calcola_distanza(parseFloat(info.lat), parseFloat(info.long)) >
		        $("#raggio").slider("option", "value"))
			data[id].tooFar = 1;
		else
			data[id].tooFar = 0;
	})

//	var base_url = grp_url + "/descr-distanza/";

//	base_url += 'params/' + p.lat() + '/' + p.lng() + '/' + lat + '/' + lon;

//	$.ajax({
//		url: base_url,
//		success: function (data) { dist = data; },
//		async:false
//	});

	return data;
}

function calcola_distanza(lat, lon) {
	var p = user.getPosition();
	var radlat1 = Math.PI * lat / 180;
	var radlat2 = Math.PI * p.lat() / 180;
	var radlon1 = Math.PI * lon / 180;
	var radlon2 = Math.PI * p.lng() / 180;
	var theta = lon - p.lng();
	var radtheta = Math.PI * theta / 180;
	var dist = Math.sin(radlat1) * Math.sin(radlat2) + Math.cos(radlat1) * Math.cos(radlat2) * Math.cos(radtheta);
	dist = Math.acos(dist);
	dist = dist * 180 / Math.PI;
	dist = dist * 60 * 1.1515;
	dist = dist * 1.609344;//km
	return dist;
}
/*
function orario() {
	var d = new Date();
	var weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

	var giorno = weekday[d.getDay()];
	var ora = d.getHours();

	if (ora < 10)
		ora = "0" + ora;

	var minuti = d.getMinutes();

	if (minuti < 10)
		minuti = "0" + minuti;

	return giorno + ": " + ora + minuti + "-" + (ora + 1) + minuti + ".";
}

function aprira(opening) {
	var aperto;
	var base_url = grp_url + "/descr-aprirap/params/";

	base_url += encodeURIComponent(opening) +
		'/' + encodeURIComponent(orario());

	$.ajax({
		url: base_url,
		success: function (data) { aperto = data; },
		async: false
	});

	switch (parseInt(aperto)) {
		case 0: return "<span style=\"color:red\">Chiuso</span>";
		case 1: return "<span style=\"color:orange\">Chiuderà nella prossima ora</span>";
		case 2: return "<span style=\"color:yellow\">Aprirà nella prossima ora</span>";
		case 3: return "<span style=\"color:yellow\">Aprirà nella prossima ora</span>";
		case 4: return "<span style=\"color:green\">Aperto</span>";
		default: return "";
	}
}
*/
$(document).ready(function() {
	inizializza_mappa();
	inizializza_tabella();
	inizializza_categorie();

	inizializza_ricerca();

	$("#CONTENT").tabs( {
show: function() {
			google.maps.event.trigger(
			    mappa, 'resize'
			);
		}
	});

	$("#raggio").slider( {
		min: 1,
		max: 5000,
		value: 1500,
slide: function(ev, ui) {
			$("#kilometri").text(ui.value);
		},
change: function() {
			if (firstreq == 0)
				$("#submit").click();
		}
	});

	$("#submit").click(function() {
		var raggio = $('#raggio').slider("value");
		var parola = $('#field').val();

		var aggrs  = [];
		var categs = [];

		$.each($('.categoria:checked'), function(i, cat) {
			aggrs.push(cat.id);
			categs.push(cat.name);
		});

		$("#loader").show();

		trova_locations(parola, raggio, aggrs, categs);
	});
});

