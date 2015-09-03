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
  gphoto2_saving_regex: /Saving file as ([^.jpg]+)/g
  gphoto2_captured_success_regex: /New file is in/g

  constructor: (
    @filename="%m-%y-%d_%H:%M:%S.jpg",
    @cwd="public/photos",
    @web_root_path="/photos") ->

  init: ->
    exec "killall capture"
    exec "killall PTPCamera"
    ids_capture = spawn("capture",["4567"],
      cwd:@cwd
    )
    in_ids_capture = false
    ids_finished = false
    gphoto2_finished = false

    ids_capture.stdout.on "data", (data) =>
      console.log("ids:"+data.toString())
    ids_capture.stderr.on "data", (data) =>
      console.log(data.toString())
      #if @received_regex.exec(data.toString())
        #if in_ids_capture
        #  emitter.emit "camera_snapped"
        #else
        #  console.log("incorrect sequence for received")
      saving = @saving_regex.exec(data.toString())
      if saving
        if in_ids_capture
          fname = saving[1] + ".jpg"
          ids_finished = {
            filename:fname,
            path: @cwd + "/" + fname,
            web_url: @web_root_path + "/" + fname
          }
          if gphoto2_finished
            emitter.emit("photo_saved", [gphoto2_finished,ids_finished])
          in_ids_capture = false

    requester.connect('tcp://localhost:4567');
    emitter = new EventEmitter()
    emitter.on "snap", () =>
      in_ids_capture = true
      ids_finished = false
      gphoto2_finished = false
      emitter.emit "camera_begin_snap"
      ids_filename = (new Date()).getTime() 
      requester.send("espresso_"+ids_filename+'.jpg');

      gphoto2_capture = spawn("gphoto2", [ "--capture-image-and-download",
                                   "--force-overwrite",
                                   "--filename=" + @filename ],
        cwd: @cwd
      )
      gphoto2_capture.stdout.on "data", (data) =>
        if @gphoto2_captured_success_regex.exec(data.toString())
          emitter.emit "camera_snapped"

        saving = @gphoto2_saving_regex.exec(data.toString())
        if saving
          fname = saving[1] + ".jpg"
          gphoto2_finished = {
            filename:fname,
            path: @cwd + "/" + fname,
            web_url: @web_root_path + "/" + fname
          }
          if ids_finished
            emitter.emit("photo_saved", [gphoto2_finished,ids_finished])


module.exports = CameraControl
