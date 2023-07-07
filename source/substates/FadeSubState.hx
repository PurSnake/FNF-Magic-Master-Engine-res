package substates;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import states.MusicBeatState;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.FlxSubState;
import flixel.FlxObject;
import flixel.FlxSprite;
import states.VoidState;
import flixel.FlxCamera;
import flixel.FlxState;
import flixel.FlxG;

using SavedFiles;

class FadeSubState extends FlxSubState {
	public static var fade:FlxSprite;

    public var targetState:FlxState;

	private var curCamera:FlxCamera = new FlxCamera();
    
    public function new(?_targetState:FlxState){
        this.targetState = _targetState;
        super();
		curCamera.bgColor = FlxColor.BLACK;
        curCamera.bgColor.alpha = 0;
		FlxG.cameras.add(curCamera);
        
        var doTransition:Void->Void = function(){
            fade = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            fade.cameras = [curCamera];
            fade.alpha = (targetState != null) ? 0 : 1;
            add(fade);
    
            FlxTween.tween(fade, {alpha: (targetState != null) ? 1 : 0}, 0.5, {onComplete: function(twn:FlxTween) {
                if(targetState != null){
                    MusicBeatState.state.persistentDraw = false;
                    FlxG.switchState(new VoidState(targetState));
                }else{
                    MusicBeatState.state.persistentUpdate = true;
                    close();
                }
            }, ease: FlxEase.linear});
        };

        var tans_script:Script = null;
        for(s in ModSupport.modDataScripts){if(s.getFunction("transition") == null){continue;} tans_script = s; break;}
        if(tans_script != null){if(tans_script.exFunction("transition", [doTransition])){return;}}
        doTransition();
	}
    
	override function close():Void {
		FlxG.cameras.remove(curCamera);
		curCamera.destroy();

		super.close();
	}
}