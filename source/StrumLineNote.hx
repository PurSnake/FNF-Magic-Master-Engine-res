package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import flixel.math.FlxMath;

import flixel.group.FlxGroup;

import Section.SwagSection;

using StringTools;

typedef StrumLineNoteJSON = {
    var staticNotes:Array<NoteJSON>;
    var gameplayNotes:Array<NoteJSON>;
    var noteSplash:String;
}

typedef NoteJSON = {
    var colorHUE:Array<Float>;
    var arrayAnims:Array<NoteAnimJSON>;

    var alpha:Float;
    var scale:Int;
    var antialiasing:Bool;
}

typedef NoteAnimJSON = {
    var anim:String;
    var symbol:String;
    var offsets:Array<Int>;
    var indices:Array<Int>;

    var fps:Int;
    var loop:Bool;
}

typedef NoteData = {
	var type:String;
	var values:Array<Dynamic>;
}

class StrumLine extends FlxGroup{
    var staticNotes:StrumStaticNotes;
    var notes:FlxTypedGroup<Note>;

    public var scrollSpeed:Float = 1;

    public var typeStrum:String = "BotPlay"; //BotPlay, Playing, Charting

    public var strumSize:Float = 110;

    public var JSONSTRUM:StrumLineNoteJSON;
    public var image:String = "NOTE_assets";
    public var noteType:String = "Default";

    public var keys:Int = 0;

    public function new(x:Float, y:Float, keys:Int, size:Float){
        strumSize = size;
        this.keys = keys;
        super();

        JSONSTRUM = cast Json.parse(Assets.getText(Paths.strumline(keys)));

        staticNotes = new StrumStaticNotes(noteType, x, y, keys, Std.int(size / keys));
        add(staticNotes);

        notes = new FlxTypedGroup<Note>();
        add(notes);
    }

    public function changeGraphic(newImage:String, newType:String){
        if(image != newImage){image = newImage;}
        if(noteType != newType){noteType = newType;}

        changeKeyNumber(keys, strumSize, true);
    }

    public function changeKeyNumber(keys:Int, size:Float, ?force:Bool = false){
        this.keys = keys;
        JSONSTRUM = cast Json.parse(Assets.getText(Paths.strumline(keys)));

        notes.forEachAlive(function(daNote:Note){
            daNote.loadGraphicNote(JSONSTRUM.gameplayNotes[daNote.noteData], noteType);
        });
        
        staticNotes.noteSize = Std.int(size / keys);
        staticNotes.changeKeys(keys, force);
    }

    public function setNotes(swagNotes:Array<SwagSection>){
        var pre_Offset:Float = PreSettings.getPreSetting("NoteOffset");
        var pre_TypeNotes:String = PreSettings.getArraySetting(PreSettings.getPreSetting("TypeNotes"));

        notes.clear();

        for(section in swagNotes){
            for(strumNotes in section.sectionNotes){
                var daSpecialData:Int = Std.int(strumNotes[4]);
                if(pre_TypeNotes == "All" || (pre_TypeNotes == "OnlyNormal" && daSpecialData == 0) || (pre_TypeNotes == "OnlySpecials" && daSpecialData != 0) || (pre_TypeNotes == "DisableBads" && daSpecialData <= 0) || (pre_TypeNotes == "DisableGoods" && daSpecialData >= 0)){
                    var daStrumTime:Float = strumNotes[0] + pre_Offset;
                    var daNoteData:Int = Std.int(strumNotes[1]);
                    var daLength:Float = strumNotes[2];
                    var daHits:Int = strumNotes[3];

                    var daOtherData:Array<NoteData> = strumNotes[5];
    
                    //noteJSON:NoteJSON, typeCheck:String, strumTime:Float, noteData:Int, ?specialType:Int = 0, ?otherData:Array<NoteData>
                    var swagNote:Note = new Note(JSONSTRUM.gameplayNotes[daNoteData], noteType, daStrumTime, daNoteData, daLength, daHits, daSpecialData, daOtherData);
                    notes.add(swagNote);
                }
            }
        }
    }

    var pre_TypeStrums:String = PreSettings.getArraySetting(PreSettings.getPreSetting("TypeLightStrums"));
    override function update(elapsed:Float){
		super.update(elapsed);

        keyShit();

        notes.forEachAlive(function(daNote:Note){
            var pre_TypeScrollSpeed:String = PreSettings.getArraySetting(PreSettings.getPreSetting("ScrollSpeedType"));
            var pre_TypeScroll:String = PreSettings.getArraySetting(PreSettings.getPreSetting("TypeScroll"));
            var pre_ScrollSpeed:Float = PreSettings.getPreSetting("ScrollSpeed");
            
            if(daNote.noteStatus == "late"){
                daNote.active = false;
                daNote.visible = false;
            }else{
                daNote.visible = true;
                daNote.active = true;
            }

            var curScrollspeed:Float = 1;
            switch(pre_TypeScrollSpeed){
                case "Scale":{curScrollspeed = scrollSpeed * pre_ScrollSpeed;}
                case "Force":{curScrollspeed = pre_ScrollSpeed;}
                case "Disabled":{curScrollspeed = scrollSpeed;}
            }

            daNote.setNoteSize(staticNotes.noteSize);
            var ySuff:Float = 0.45 * (Conductor.songPosition - daNote.strumTime) * FlxMath.roundDecimal(curScrollspeed, 2);
            if(staticNotes.members[daNote.noteData].exists){
                if(pre_TypeScroll == "DownScroll"){
                    daNote.y = (staticNotes.members[daNote.noteData].y + ySuff);
                }else if(pre_TypeScroll == "UpScroll"){
                    daNote.y = (staticNotes.members[daNote.noteData].y - ySuff);
                }

                daNote.visible = staticNotes.members[daNote.noteData].visible;
                daNote.x = staticNotes.members[daNote.noteData].x;
                daNote.angle = staticNotes.members[daNote.noteData].angle;
                daNote.alpha = staticNotes.members[daNote.noteData].alpha;
            }else{
                daNote.visible = false;
            }

            if(daNote.noteStatus == "Pressed"){
                if(pre_TypeStrums == "All" || pre_TypeStrums == "OnlyOtherStrums"){
                    staticNotes.animNote(daNote.noteData, "confirm");
                }

                if(daNote.noteHits > 0 && daNote.noteLength > 20){
                    daNote.noteStatus = "MultiTap";
                    daNote.strumTime += daNote.noteLength;
                    daNote.noteHits--;
                }else{
                    daNote.active = false;

                    daNote.kill();
                    notes.remove(daNote, true);
                    daNote.destroy();
                }
            }
        });
	}

    private function keyShit():Void{
        if(typeStrum == "Playing"){
            var jPressArray:Array<Bool> = Controls.getStrumBind(keys + "K", "JUST_PRESSED");
            var holdArray:Array<Bool> = Controls.getStrumBind(keys + "K", "PRESSED");
            var releaseArray:Array<Bool> = Controls.getStrumBind(keys + "K", "JUST_RELEASED");

            staticNotes.forEach(function(staticStrum:StrumNote){
                if(staticStrum.animation.curAnim.name == "static" && holdArray[staticStrum.ID]){
                    staticStrum.playAnim("pressed");
                }

                if(releaseArray[staticStrum.ID]){
                    staticStrum.playAnim("static");
                }
            });
    
            notes.forEachAlive(function(daNote:Note){
                if(daNote.noteStatus == "CanBeHit" && jPressArray[daNote.noteData]){
                    if(pre_TypeStrums == "All" || pre_TypeStrums == "OnlyOtherStrums"){
                        staticNotes.animNote(daNote.noteData, "confirm");
                    }
    
                    daNote.noteStatus = "Pressed";
                }
            });
        }else if(typeStrum == "BotPlay"){
            staticNotes.forEach(function(staticStrum:StrumNote){
                if(staticStrum.animation.curAnim.name == "confirm" && staticStrum.animation.finished){
                    staticStrum.playAnim("static");
                }
            });

            notes.forEachAlive(function(daNote:Note){
                if(daNote.noteStatus == "CanBeHit"){
                    if(pre_TypeStrums == "All" || pre_TypeStrums == "OnlyOtherStrums"){
                        staticNotes.animNote(daNote.noteData, "confirm");
                    }
    
                    daNote.noteStatus = "Pressed";
                }
            });
        }else if(typeStrum == "Charting"){
            notes.forEachAlive(function(daNote:Note){
                if(daNote.noteStatus == "CanBeHit"){
                    staticNotes.animNote(daNote.noteData, "confirm");
                }
            });
        }
    }
}

class StrumStaticNotes extends FlxTypedGroup<StrumNote> {
    public var x:Float = 0;
    public var y:Float = 0;

    public var curKeys:Int = 4;
    public var noteSize:Int = 110;

    public var JSON:Array<NoteJSON>;
    public var typeCheck:String = "Default";

    public function new(typeCheck:String, x:Float, y:Float, keys:Int = 4, ?size:Int){
        if(typeCheck != null){this.typeCheck = typeCheck;}
        this.x = x;
        this.y = y;
        if(size != null){noteSize = size;}
        super();
        
        changeKeys(curKeys, true);
    }

    public function animNote(noteId:Int, anim:String){
        this.members[noteId].playAnim(anim, true);
    }

    public function setNoteGraphic(noteId:Int, specialId:Int = 0, ?newJSON:NoteJSON, ?newTypeCheck:String){
        var curJSON:NoteJSON = newJSON;
        if(curJSON == null){curJSON = JSON[noteId];}

        var curType:String = newTypeCheck;
        if(curType == null){curType = typeCheck;}

        this.members[noteId].loadGraphicStrum(curJSON, curType);
    }

    public function changeKeys(keys:Int, ?force:Bool = false){
        if(curKeys != keys || force){
            curKeys = keys;
            
            var newJSON:StrumLineNoteJSON = cast Json.parse(Assets.getText(Paths.strumline(curKeys)));
            JSON = newJSON.staticNotes;
    
            if(this.members.length > 0){
                for(strum in this.members){
                    FlxTween.tween(strum, {alpha: 0, y: strum.y + (strum.height / 2)}, (0.5 * (strum.noteData + 1) / this.members.length), {
                        ease: FlxEase.quadInOut,
                        onComplete: function(twn:FlxTween){
                            this.members.remove(strum);
                        }
                    });
                }
            }
            
            for(i in 0...curKeys){
                var strum:StrumNote = new StrumNote(JSON[i], typeCheck, x + (i * noteSize), y - (noteSize / 2), i);
                strum.ID = i;
                strum.alpha = 0;
                strum.setNoteScale(noteSize);
                add(strum);
    
                FlxTween.tween(strum, {alpha: 1, y: y}, (0.5 * (strum.noteData + 1) / curKeys), {ease: FlxEase.quadInOut});
            }
        }
    }
}

class StrumNote extends FlxSprite{
	public var noteData:Int = 0;
    public var specialData:Int = 0;

    public var animOffsets:Map<String, Array<Dynamic>>;

    public var scaleNote:Int;

	public function new(JSON:NoteJSON, typeNote:String, x:Float, y:Float, leData:Int, ?specialData:Int = 0){
        this.specialData = specialData;
		noteData = leData;
        super(x, y);

        #if (haxe >= "4.0.0")
		    animOffsets = new Map();
		#else
		    animOffsets = new Map<String, Array<Dynamic>>();
		#end

        alpha = JSON.alpha;

		scaleNote = JSON.scale;

        loadGraphicStrum(JSON, specialData, typeNote);

        if(JSON.antialiasing){
            antialiasing = PreSettings.getPreSetting("Antialiasing");
        }else{
            antialiasing = false;
        }

        playAnim("static");
	}

    public function loadGraphicStrum(newJSON:NoteJSON, ?specialData:Int, ?newTypeNote:String = "Default"){
        animOffsets.clear();

        if(specialData != null){this.specialData = specialData;}
        var image = NoteExtras.getNoteImage(specialData);

        frames = Paths.getNoteAtlas(image, newTypeNote);

        var anims = newJSON.arrayAnims;
        for(anim in anims){
            if(anim.indices != null && anim.indices.length > 0){
                animation.addByIndices(anim.anim, anim.symbol, anim.indices, "", anim.fps, anim.loop);
            }else{
                animation.addByPrefix(anim.anim, anim.symbol, anim.fps, anim.loop);
            }

            if(anim.offsets != null && anim.offsets.length > 1){
                animOffsets[anim.anim] = [anim.offsets[0], anim.offsets[1]];
            }
        }
    }

    public function setNoteScale(scale:Int){
        setGraphicSize(scale * scaleNote);
    }

    override function update(elapsed:Float){
		super.update(elapsed);
	}

    public function playAnim(anim:String, ?force:Bool = false){
		animation.play(anim, force);

        var daOffset = animOffsets.get(anim);
        if(animOffsets.exists(anim)){
            offset.set(daOffset[0], daOffset[1]);
        }else{
            offset.set(0, 0);
        }
	}
}

class Note extends FlxSprite {
    //General Variables
    public var strumTime:Float = 1;

    public var noteLength:Float = 0;
    public var noteHits:Float = 0; // Determinate if MultiTap o Sustain

    public var typeSustain:String = "Normal"; // CurNormal Types

	public var noteData:Int = 0;
    public var specialData:Int = 0;
	public var otherData:Array<NoteData> = [];

    //Image Variables
    public var animOffsets:Map<String, Array<Dynamic>>;

    public var scaleNote:Int;

    //Other Variables
    public var noteStatus:String = "Spawned"; //status: Spawned, CanBeHit, Pressed, Late, MultiTap

	public function new(newJSON:NoteJSON, newTypeCheck:String, strumTime:Float, noteData:Int, noteLength:Float, noteHits:Int, ?specialType:Int = 0, ?otherData:Array<NoteData>){
        this.strumTime = strumTime;
		this.noteData = noteData;
        this.noteLength = noteLength;
        this.noteHits = noteHits;
        super();

        #if (haxe >= "4.0.0")
		    animOffsets = new Map();
		#else
		    animOffsets = new Map<String, Array<Dynamic>>();
		#end

        loadGraphicNote(newJSON, newTypeCheck);
	}

    public function loadGraphicNote(newJSON:NoteJSON, ?newTypeCheck:String = "Default"){
        animOffsets.clear();
        animation.destroyAnimations();

        var image = NoteExtras.getNoteImage(specialData);

        frames = Paths.getNoteAtlas(image, newTypeCheck);

        var anims = newJSON.arrayAnims;
        for(anim in anims){
            if(anim.indices != null && anim.indices.length > 0){
                animation.addByIndices(anim.anim, anim.symbol, anim.indices, "", anim.fps, anim.loop);
            }else{
                animation.addByPrefix(anim.anim, anim.symbol, anim.fps, anim.loop);
            }

            if(anim.offsets != null && anim.offsets.length > 1){
                animOffsets[anim.anim] = [anim.offsets[0], anim.offsets[1]];
            }
        }

        alpha = newJSON.alpha;
		scaleNote = newJSON.scale;

        if(newJSON.antialiasing){antialiasing = PreSettings.getPreSetting("Antialiasing");
        }else{antialiasing = false;}
    }

	public function setNoteSize(size:Int){
        setGraphicSize(size * scaleNote);
    }

    override function update(elapsed:Float){
		super.update(elapsed);

        switch(typeSustain){
            case "Normal":{playAnim("static");}
            case "Sustain":{playAnim("sustain");}
            case "SustainEnd":{playAnim("end");}
        }

        if(strumTime > Conductor.songPosition - Conductor.safeZoneOffset && strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * 0.5)){
            noteStatus = "CanBeHit";
        }

        if(strumTime < Conductor.songPosition - Conductor.safeZoneOffset && noteStatus != "Pressed"){
            noteStatus = "Late";
        }
	}

    public function playAnim(anim:String, ?force:Bool = false){
		animation.play(anim, force);

        var daOffset = animOffsets.get(anim);
        if(animOffsets.exists(anim)){
            offset.set(daOffset[0], daOffset[1]);
        }else{
            offset.set(0, 0);
        }
	}
}

class NoteExtras{
    public static function getNoteImage(specialData:Int = 0):String {
        switch(specialData){
            default:{return "NOTE_assets";}
            case 1:{return "Blood_NOTE_ASSETS";}
        }
    }
}