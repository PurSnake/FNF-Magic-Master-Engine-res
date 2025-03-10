package substates;

import Script;

class CustomScriptSubState extends MusicBeatSubstate {
    public var custom_script:Script;

    public function new(new_script:Script, onClose:Void->Void = null):Void {
        custom_script = new_script;
        super(onClose);
        tempScripts.set(new_script.Name, new_script);
    }
}
