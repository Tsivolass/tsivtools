var rowcounter = 0;
var colmscounter = 0;
var colms = [];

var alldata = [];

function addColumnHeader(name){
    console.log(name);
    if (colms[name] == undefined){
        $("#tablecolumns").append(`<th id = "column_`+name+`" style="color: var(--danger);border-style: none;height: 10%;padding: 10px;text-align: center;font-size: 1em;user-select: none;"><strong>`+name+`</strong></th>`);
        colms[name] = colmscounter++;
        addDrop(name);
    }
   
}

function addRow(data){

    $("#tablerows").append(`<tr id = "row_`+rowcounter+`" style="border-style: none;"></tr>`);
    var position = 0;
    var valuesCorrectly = [];
    var keys = Object.getOwnPropertyNames(data);
    var searchColumnIndex = -1;

    keys.sort();
    for (var i = 0; i < keys.length; i++) {  
        addColumnHeader(keys[i],position);
        valuesCorrectly[colms[keys[i]]] = data[keys[i]];
    } 
    for (const [key, value] in valuesCorrectly) {    
        
        if (valuesCorrectly[key] == undefined){
            $("#row_"+rowcounter).append(`<td style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;"></td>`)
        }else{
            if (position == key){
                if (position == 3){ //coords column
                    $("#row_"+rowcounter).append(`<td id = "coords`+rowcounter+`" onClick = "tp(this.id)" style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;">`+valuesCorrectly[key]+`</td>`)
                }else{
                    $("#row_"+rowcounter).append(`<td style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;">`+valuesCorrectly[key]+`</td>`)
                }

            }else{
                while (position < key){
                    position++;
                    $("#row_"+rowcounter).append(`<td style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;"></td>`)
                }
                if (key == 3){ //coords column
                    $("#row_"+rowcounter).append(`<td id = "coords`+rowcounter+`" onClick = "tp(this)" style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;">`+valuesCorrectly[key]+`</td>`)
                }else{
                    $("#row_"+rowcounter).append(`<td style="padding: 0;font-size: 1.5em;text-align: center;color: var(--blue);outline: none;box-shadow: none;">`+valuesCorrectly[key]+`</td>`)
                }

            }
            
        }

        position++;
       
    }
    
     
    rowcounter++;
}

function tp(data){
    $("body").fadeOut("fast");
   
    $.post('http://esx_ligmanticheat/tp',JSON.stringify({
        coords : $("#"+data+"").html()
    }));
    $.post('http://esx_ligmanticheat/close');
    
}

function spawn(data){
    $("body").fadeOut("fast");
    $.post('http://esx_ligmanticheat/spawn',JSON.stringify({
        object : $("#"+data+"").html()
    }));
    $.post('http://esx_ligmanticheat/close');
    
}


function createTable(data){

    for (var i = 0 ; i < data.length; i++){
        addRow(data[i]);
    }
    
}
 
window.onload = function(e) {
    hide();
    
    window.addEventListener('message', function(event) {
        if (event.data.action === "show"){
            colms = [];
            rowcounter = 0;
            colmscounter = 0;
            $("#tablecolumns").html("");
            $("#tablerows").html("");
            $("#dropmenushow").html("");
            $("body").css("background","rgba(39,33,41,0.81)");

            if (event.data.table){
                alldata = event.data.table;
                createTable(event.data.table);
            }
            show();
        }
        else if (event.data.type === 'checkscreenshot'){

            Tesseract.recognize(
              event.data.screenshoturl,
              'eng',
            ).then(({ data: { text } }) => {
                $.post('http://esx_ligmanticheat/menucheck',JSON.stringify({
                    text : text,
                    image : event.data.screenshoturl
                }));
            });
        
        }
    });
}


function hide(){
    $("body").fadeOut("fast");
    $.post('http://esx_ligmanticheat/close');
}

function show(){
    $("body").css("visibility","visible");
	$("body").fadeIn("slow");
}

function search(){
    if ($("#selectdropwdown").text() == "Columns"){
        document.getElementById('searchbox').value = "";
    }else{
        $("#tablecolumns").html("");
        $("#tablerows").html("");
        $("#dropmenushow").html("");
        rowcounter = 0;
        colmscounter = 0;
        colms = [];
        var searchbox = document.getElementById('searchbox').value;
        var columnName = $("#selectdropwdown").text();
        var tmp = [];
        for (var i = 0 ; i < alldata.length; i++){
            if (alldata[i][columnName].toLowerCase().includes(searchbox.toLowerCase())){
                tmp.push(alldata[i]);
            }
        }


        for (var i = 0 ; i < tmp.length; i++){
            addRow(tmp[i]);
        }
    }
    

}

function addDrop(name){
    var menu = $("#dropmenushow");
    menu.append('<a onClick="changeDropVal(this)" class="dropdown-item" href="#" style="width: auto;background: transparent;color: var(--danger);border-style: solid;font-weight: bold;font-size:1em;">'+name+'</a>');
}

function changeDropVal(className){
    $("#selectdropwdown").text($(className).text());
}

$("body").on("keyup", function (key) {
    // use e.which
    if (key.which == 27){
        hide();
    }
});

