express = require "express"
jade = require "jade"
http = require "http"
sys = require "sys"
fs = require "fs"
yaml = require "yaml"
dotenv = require "dotenv"
exec = require("child_process").exec

dotenv.load()
console.log("printer is: #{process.env.PRINTER_ENABLED}")

PhotoFileUtils = require("./lib/photo_file_utils")
StubCameraControl = require("./lib/stub_camera_control")
CameraControl = require("./lib/camera_control")
ImageCompositor = require("./lib/image_compositor")

exp = express()
web = http.createServer(exp)

exp.configure ->
  exp.set "views", __dirname + "/views"
  exp.set "view engine", "jade"
  exp.use express.json()
  exp.use express.methodOverride()
  exp.use exp.router
  exp.use express.static(__dirname + "/public")

exp.get "/", (req, res) ->
  res.render "index",
    title: "shmile"
    extra_css: []

exp.get "/gallery", (req, res) ->
  res.render "gallery",
    title: "gallery!"
    extra_css: [ "photoswipe/photoswipe" ]
    image_paths: PhotoFileUtils.composited_images(true)

# FIXME/ahao This global state is no bueno.
State = image_src_list: []

ccKlass = if process.env['STUB_CAMERA'] is "true" then StubCameraControl else CameraControl
camera = new ccKlass().init()

camera.on "photo_saved", (images) ->
    State.image_src_list.push images

io = require("socket.io").listen(web)
web.listen 3000
io.sockets.on "connection", (websocket) ->
  sys.puts "Web browser connected"
  
  camera.on "camera_begin_snap", ->
    websocket.emit "camera_begin_snap"

  camera.on "camera_snapped", ->
    websocket.emit "camera_snapped"

  camera.on "photo_saved", (images_list) ->
    websocket.emit "photo_saved",
      images_list

  websocket.on "snap", () ->
    camera.emit "snap"

  websocket.on "all_images", ->

  websocket.on "composite", ->
    compositer = new ImageCompositor(State.image_src_list).init()
    compositer.emit "composite"
    compositer.on "composited", (output_file_path) ->
      console.log "Finished compositing image. Output image is at ", output_file_path
      State.image_src_list = []

      # Control this with PRINTER=true or PRINTER=false
      if process.env.PRINTER_ENABLED is "true"
        console.log "Printing image at ", output_file_path
        exec "lpr #{output_file_path}"
      websocket.broadcast.emit "composited_image", PhotoFileUtils.photo_path_to_url(output_file_path)

    compositer.on "generated_thumb", (thumb_path) ->
      websocket.broadcast.emit "generated_thumb", PhotoFileUtils.photo_path_to_url(thumb_path)
