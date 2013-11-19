File = require '../models/file'
fs = require 'fs'

## Helpers ##

findFile = (id, callback) ->
    File.find id, (err, file) =>
        if err or not file
            callback "File not found"
        else
            callback null, file 

## Actions ##

module.exports.all = (req, res) ->
    File.all (err, files) ->
        if err
            res.send error: true, msg: "Server error occured", 500
        else
            res.send files

module.exports.create = (req, res) ->
    file = req.files["file"]
    File.create req.body, (err, newfile) =>
        if err
            res.send error: true, msg: "Server error while creating file.", 500
        else
            newfile.attachBinary file.path, {"name": "file"}, (err) ->
                if err
                    console.log "[Error]: " + err
                fs.unlink file.path, (err) ->
                    if err
                        console.log 'Could not delete', file.path
                    res.send newfile, 200

module.exports.find = (req, res) ->
     findFile req.params.id, (err, file) ->
        if err
            res.send error: true, msg: err, 404
        else
            res.send file

module.exports.modify = (req, res) ->
    if not req.body.name or req.body.name == ""
        res.send error: true, msg: "No filename specified", 404
    else
        newName = req.body.name

        findFile req.params.id, (err, fileUpdated) ->
            if err
                res.send error: true, msg: err, 404
            else
                # test if the filename is available
                conflict = false
                File.all (err, files) =>

                    conflict = false
                    for file in files
                        # it's not the same file
                        if not (fileUpdated.id is file.id)
                            # but has the same path and the desired name
                            if (fileUpdated.path is file.path) and (newName is file.name)
                                conflict = true
                                res.send error:true, msg: "This filename is already in use", 400

                    if not conflict
                        fileUpdated.updateAttributes name: newName, (err) =>
                            if err
                                compound.logger.write err
                                res.send error: 'Cannot modify file', 500
                            else
                                res.send success: 'File succesfuly modified', 200

processAttachement = (req, res, download) ->
    id = req.params.id
    findFile id, (err, file) =>
        if err
            res.send error: true, msg: err, 404
        else
            res.setHeader 'Content-Disposition', (if download then "attachment; filename=" + file.name else "inline")
            stream = file.getBinary "file", (err, resp, body) =>
                if err
                    res.send error: true, msg: err, 500
            stream.pipe(res)

module.exports.getAttachment = (req, res) ->
    processAttachement req, res, false

module.exports.downloadAttachment = (req, res) ->
    processAttachement req, res, true


module.exports.destroy = (req, res) ->
    findFile req.params.id, (err, file) ->
        if err
            res.send error: true, msg: err, 404
        else
            file.removeBinary "file", (err, resp, body) =>
                file.destroy (err) =>
                    if err
                        compound.logger.write err
                        res.send error: 'Cannot destroy file', 500
                    else
                        res.send success: 'File succesfuly deleted', 200
