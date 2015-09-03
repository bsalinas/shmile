EventEmitter = require("events").EventEmitter
spawn = require("child_process").spawn
exec = require("child_process").exec
zmq       = require('zmq')
requester = zmq.socket('req')
###
# Interface to gphoto2 via the command line.
#
# It's highly fragile and prone to failure, so if anyone wants
# to take a crack at redoing the node-gphoto2 bindings, be my
# guest...
###
class CameraControl
  received_regex: /Capturing image/g
  saving_regex: /Saving image to ([^.jpg]+)/g
  captured_success_regex: /Saving image to ([^.jpg]+)/g

  constructor: (
    @cwd="public/photos",
    @web_root_path="/photos") ->

  init: ->
    exec "killall capture"
    ids_capture = spawn("capture",["4567"],
      cwd:@cwd
    )
    in_capture = false

    ids_capture.stdout.on "data", (data) =>
      console.log("ids:"+data.toString())
    ids_capture.stderr.on "data", (data) =>
      console.log(data.toString())
      if @received_regex.exec(data.toString())
        if in_capture
          emitter.emit "camera_snapped"
          onCaptureSuccess() if onCaptureSuccess?
        else
          console.log("incorrect sequence for received")
      saving = @saving_regex.exec(data.toString())
      if saving
        if in_capture
          fname = saving[1] + ".jpg"
          emitter.emit(
            "photo_saved",
            fname,
            @cwd + "/" + fname,
            @web_root_path + "/" + fname
          )
          onSaveSuccess() if onSaveSuccess?

    requester.connect('tcp://localhost:4567');
    emitter = new EventEmitter()
    emitter.on "snap", (onCaptureSuccess, onSaveSuccess) =>
      in_capture = true
      emitter.emit "camera_begin_snap"
      filename = (new Date()).getTime() 
      requester.send("test_"+filename+'.jpg');

module.exports = CameraControl
