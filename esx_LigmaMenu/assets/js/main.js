var showPower = false;
var showReason = false;
var showType = false;
var nui;
var disabled = false;
var identifier = '';

function submit(){
    var hours = $("#daysbox").val();
    /* var power = $("#powerbox").val(); */
    var selectdropwdown = $("#selectdropwdown").text();
    var reason = $("#reasonbox").val();
    var internetcafe = false;
    hours = Number(hours);
    if( hours == 0 && !document.getElementById('formCheck-1').checked){
        alert("Please enter days");
        return;
    }
    if(document.getElementById('formCheck-1').checked){
        hours = -1;
    }
    if (selectdropwdown.toLowerCase() == "select"){
        alert("Enter Type");
        return;
    }
    var vtype = selectdropwdown.toLowerCase();
    if (document.getElementById('formCheck-2') != null){
        internetcafe = document.getElementById('formCheck-2').checked;
    }
    showPower = false;
    showReason = false;
    showType = false;
    console.log(nui);
    $("#submitbut").css("visibility","hidden");
    $("#submitbut").html("");
    $("#submitdv").html("");
    $("#maindiv").fadeOut("fast");
    $.post('http://esx_LigmaMenu/'+nui,JSON.stringify({
        hours : hours,
        type : vtype,
        reason : reason,
        identifier : identifier,
        internetcafe: internetcafe
    })); 
    nui = undefined;
}

function changeDropVal(className){
    $("#selectdropwdown").text($(className).text());
}

function addDrop(name){
    var menu = $("#dropmenushow");
    menu.append("<a class=\"dropdown-item\" onClick=\"changeDropVal(this)\" href=\"#\">"+name+"</a>");
    menu.append("<div class=\"dropdown-divider\"></div>");
}

function addPowerDiv(){
    $("#wholediv").append("<div id=\"powerdiv\" style=\"background: transparent;height: 16%;width: 100%;\"><p class=\"d-inline\" style=\"color: rgb(241,220,36);font-size: 2em;margin-top: 59px;padding-top: 0%;margin-left: 3%;line-height: 58px;\">Power:</p><input type=\"number\" id=\"powerbox\" min=\"60\" max=\"100\" style=\"width: 33%;height: 41%;margin-left: 3%;border-color: rgb(96,139,181);color: rgb(241,220,36);font-family: 'Abril Fatface', cursive;border-radius: 8px;background: transparent;text-align: center;padding-top: 0px;margin-top: 3%;\"/></div>");
}

function addReasonDiv(){
    $("#wholediv").append("<div id=\"reasondiv\" style=\"background: transparent;height: 16%;width: 100%;\"><p class=\"d-inline\" style=\"color: rgb(241,220,36);font-size: 2em;margin-top: 59px;padding-top: 0%;margin-left: 3%;line-height: 64px;\">Reason:</p><input type=\"text\" id=\"reasonbox\" style=\"margin-top: 3%;height: 41%;margin-left: 3%;width: 33%;border-style: solid;border-color: rgb(96,139,181);border-radius: 8px;background: transparent;color: rgb(241,220,36);font-family: 'Abril Fatface', cursive;\"/></div>");
}

function addTypeDiv(){
    $("#wholediv").append("<p class=\"d-inline \" style=\"color: rgb(241,220,36);font-size: 2em;padding-top: 0%;margin-left: 3%;\">Type:</p><div class=\"dropdown\"><button class=\"btn btn-primary dropdown-toggle \" data-toggle=\"dropdown\" aria-expanded=\"false\" id=\"selectdropwdown\" type=\"button\" style=\"margin-left: 8%;margin-top: 3%;color: rgb(241,220,36);font-family:  cursive;\">Select</button><div class=\"dropdown-menu\"id=\"dropmenushow\"></div></div><div></div></div>");
}

function addDaysDiv(label){
    $("#wholediv").append('<div id="daysdiv" style="background: transparent;height: 16%;width: 100%;"><p class="d-inline" id="divara" style="color: rgb(241,220,36);font-size: 2em;margin-top: 59px;padding-top: 0%;margin-left: 3%;line-height: 57px;">'+label+':</p><input type="number" id="daysbox" min="1" max="356" style="width: 33%;height: 41%;margin-left: 3%;border-color: rgb(96,139,181);color: rgb(241,220,36);font-family: \'Abril Fatface\', cursive;border-radius: 8px;background: transparent;text-align: center;padding-top: 0px;margin-top: 3%;"/></div>');
}

function forever(){
    if (!disabled){
        disabled = true;
        $("#daysbox").val("");
        $("#daysbox").attr("disabled", "disabled");

    }else{
        disabled = false;
        $("#daysbox").removeAttr("disabled");
    }
}

function addCheckBoxDiv(){
    $("#wholediv").append('<div id="checkboxdiv" style="width: 90%;height: 5%;background: transparent;margin-left: 5%;"><div class="form-check" style="margin-left: 9%;background: transparent;"><input onClick=forever() type="checkbox" class="form-check-input" id="formCheck-1" /><label class="form-check-label" for="formCheck-1" style="color: rgb(241,220,36);font-family: \'Abril Fatface\', cursive;">Forever</label></div></div>');
}

function addInternetCheckBoxDiv(){
    $("#wholediv").append('<div id="checkboxdiv" style="width: 90%;height: 5%;background: transparent;margin-left: 5%;"><div class="form-check" style="margin-left: 9%;background: transparent;"><input  type="checkbox" class="form-check-input" id="formCheck-2" /><label class="form-check-label" for="formCheck-2" style="color: rgb(241,220,36);font-family: \'Abril Fatface\', cursive;">Internet Cafe</label></div></div>');
}
    
function addsubmitdiv(){
    
    $("#wholediv").append('<div id="submitdv" style="width: 100%;background: transparent;height: 14%;border-radius: 0px;border: 0px none transparent;"><button class="btn btn-primary" id="submitbut" type="button" style="padding-right: 12px;color: rgb(241,220,36);font-family: \'Abril Fatface\', cursive;" onclick="submit()">Submit</button></div>');
}

function addTitleDiv(title){
    $("#wholediv").append('<div style="width: 100%;height: 20%;background: transparent;"><p id="title" style="color: rgb(241,220,36);font-family: \'Abril Fatface\', cursive;font-size: 4em;margin-left: 0%;text-align: center;">'+title+'</p></div>');
}

function show(){
    $("#maindiv").css("visibility","visible");
	$("#maindiv").fadeIn("slow");
	
}

function hide(){
	$("#maindiv").fadeOut( "fast");
}


window.onload = function(e) {
    hide();
    window.addEventListener('message', function(event) {
        var daysLabel;
        if (event.data.action === "show"){ 
            if (event.data.identifier != undefined){
                identifier = event.data.identifier;
            }else{
                identifier = "";
            }
            $("#wholediv").html("");
            nui = event.data.uaction;
            if (event.data.uaction == "ban"){
                showReason = true;
                daysLabel = "Hours";
                addTitleDiv("Ban");
                addDaysDiv(daysLabel);
                
                
                $("#submitbut").css("margin-left","37%");
                addCheckBoxDiv();
                addReasonDiv();
                addInternetCheckBoxDiv();
            }else if (event.data.uaction == "priority"){
                showPower = true;
                daysLabel = "Days";
                addTitleDiv("Priority");
                addDaysDiv(daysLabel);
                addCheckBoxDiv();
                addTypeDiv();
                for (var x = 0; x < event.data.priorities.length; x++){
                    addDrop(event.data.priorities[x].label);
                }
            }else if (event.data.uaction == "vmenu"){
                showType = true;
                daysLabel = "Days";
                addTitleDiv("Vmenu");
                addDaysDiv(daysLabel);
               
                addCheckBoxDiv();
                addTypeDiv();
                addDrop("Donate");
                addDrop("Helper");
                addDrop("Mod");
                addDrop("Admin");
                addDrop("Owner");
                
            }
            addsubmitdiv();
            show();
    
        }
        
        if (event.data.action === "hide"){
            showPower = false;
            showReason = false;
            showType = false;
            hide();
        } 
        
        
    });
} 

    
$("body").on("keyup", function (key) {
    // use e.which
    if (key.which == 27){
        showPower = false;
        showReason = false;
        showType = false;
        nui = undefined;
        $.post('http://esx_LigmaMenu/close');
        hide();
    }
});

    
