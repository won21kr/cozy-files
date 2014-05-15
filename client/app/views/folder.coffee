BaseView = require '../lib/base_view'
FilesView = require './files'
BreadcrumbsView = require "./breadcrumbs"
ProgressbarView = require "./progressbar"
ModalView = require "./modal"
ModalShareView = require './modal_share'

File = require '../models/file'
FileCollection = require '../collections/files'

Helpers = require '../lib/folder_helpers'

module.exports = class FolderView extends BaseView

    template: require './templates/folder'

    events: ->
        'click a#button-new-folder'    : 'prepareNewFolder'
        'click a#button-upload-new-file': 'onUploadNewFileClicked'
        'click #new-folder-send'       : 'onAddFolder'
        'click #cancel-new-folder'     : 'onCancelFolder'
        'click #upload-file-send'      : 'onAddFile'
        'click #cancel-new-file'       : 'onCancelFile'
        'click #share-state'           : 'onShareClicked'

        'keyup input#search-box'       : 'onSearchKeyPress'
        'keyup input#inputName'        : 'onAddFolderEnter'

    initialize: (options) ->
        @model = options.model
        @breadcrumbs = options.breadcrumbs
        @breadcrumbs.setRoot @model

        #@setDragNDrop()


    # Set Drag and drop properly.
    setDragNDrop: ->
        prevent = (e) ->
            e.preventDefault()
            e.stopPropagation()
        @$el.on "dragover", prevent
        @$el.on "dragenter", prevent
        @$el.on "drop", (e) =>
            @onDragAndDrop(e)

    getRenderData: ->
        model: @model

    afterRender: ->
        # add breadcrumbs view
        @breadcrumbsView = new BreadcrumbsView @breadcrumbs
        @$("#crumbs").append @breadcrumbsView.render().$el

        @filesList = new FilesView el: @$("#files"), model: @model
        @filesList.render()

    # Display and re-render the contents of the folder
    changeActiveFolder: (folder) ->
        # register the model
        @stopListening @model
        @model = folder
        @listenTo @model, 'change', -> @changeActiveFolder @model

        # update breadcrumbs
        @breadcrumbs.push folder
        if folder.id is "root"
            @$("#crumbs").css opacity: 0.5
        else
            @$("#crumbs").css opacity: 1

        # see, if we should display add/upload buttons
        if folder.get("type") is "folder"
            @$("#upload-buttons").show()
        else
            @$("#upload-buttons").hide()

        # manage share state button
        shareState = $ '#share-state'
        if @model.id isnt "root"
            shareState.show()
            clearance = @model.get 'clearance'
            if clearance is 'public'
                shareState.html "#{t('public')}&nbsp;"
                shareState.append $ '<span class="fa fa-globe"></span>'
            else if clearance and clearance.length > 0
                shareState.html "#{t('shared')}&nbsp;"
                shareState.append $ "<span class='fa fa-users'>" \
                                    + "</span>"
                shareState.append $ "<span>&nbsp;#{clearance.length}</span>"
            else
                shareState.html "#{t('private')}&nbsp;"
                shareState.append $ '<span class="fa fa-lock"></span>'
        else
            shareState.hide()

        # folder 'download zip' link
        zipLink = "folders/#{@model.get('id')}/zip/#{@model.get('name')}"
        @$('#download-link').attr 'href', zipLink

        @$("#loading-indicator").spin 'tiny'
        # add files view
        @model.findFiles
            success: (files) =>

                # mark files as files
                file.type = "file" for file in files

                @model.findFolders
                    success: (folders) =>

                        # mark folders as folders
                        folder.type = "folder" for folder in folders
                        @filesList.collection.reset folders.concat(files)
                        @$("#loading-indicator").spin()
                    error: (error) =>
                        console.log error
                        new ModalView t("modal error"), t("modal error get folders"), t("modal ok")
                        @$("#loading-indicator").spin()
            error: (error) =>
                console.log error
                new ModalView t("modal error"), t("modal error get files"), t("modal ok")

    onUploadNewFileClicked: ->
        $("#dialog-upload-file .progress-name").remove()

    # Upload/ new folder
    prepareNewFolder: ->
        # display upload folder form only if it is supported
        uploadDirectoryInput = @$("#folder-uploader")[0]
        supportsDirectoryUpload = uploadDirectoryInput.directory or
                                  uploadDirectoryInput.mozdirectory or
                                  uploadDirectoryInput.webkitdirectory or
                                  uploadDirectoryInput.msdirectory

        $("#dialog-new-folder .progress-name").remove()

        if supportsDirectoryUpload
          @$("#folder-upload-form").removeClass('hide')

        setTimeout () =>
            @$("#inputName").focus()
        , 500

    onCancelFolder: ->
        @$("#inputName").val("")


    onAddFolderEnter: (e) ->
        if e.keyCode is 13
            e.preventDefault()
            e.stopPropagation()
            @onAddFolder()

    onAddFolder: =>
        prefix = @model.repository()

        folder = new File
            name: @$('#inputName').val()
            path: prefix
            type: "folder"
        @$("#inputName").val("")

        files = @$('#folder-uploader')[0].files

        if not files.length and folder.validate()
            new ModalView t("modal error"), t("modal error no data"), t("modal ok")
            return

        if not folder.validate()
            @filesList.addFolder folder

        if files.length
            # create the necessary (nested) folder structure
            dirsToCreate = Helpers.nestedDirs(files)
            for dir in dirsToCreate
                # figure out the name and path for the folder
                dir = Helpers.removeTralingSlash(dir)
                parts = dir.split('/')
                path = prefix + "/" + parts[...-1].join('/')
                path = Helpers.removeTralingSlash(path)

                nFolder = new File
                    name: parts[-1..][0]
                    path: path
                    type: "folder"
                response = @filesList.addFolder nFolder, true
                # stop if the folder already exists
                if response instanceof ModalView
                    return

            # now that the required folder structure was created, upload files
            # filter out . and ..
            files = (file for file in files when (file.name isnt "." and file.name isnt ".."))
            for file in files
                relPath = file.relativePath or file.mozRelativePath or file.webkitRelativePath or file.msRelativePath
                file.path = prefix + "/" + Helpers.dirName(relPath)
                response = @filesList.addFile file, true
                # stop if the file already exists
                if response instanceof ModalView
                    return

    onAddFile: =>
        for attach in @$('#uploader')[0].files
            @filesList.addFile attach
        @$('#uploader').val("")

    onCancelFile: ->
        @$("#uploader").val("")

    onDragAndDrop: (e) =>
        e.preventDefault()
        e.stopPropagation()

        # send file
        atLeastOne = false
        for attach in e.dataTransfer.files
            if attach.type is ""
                new ModalView t("modal error"), "#{attach.name} #{t('modal error file invalid')}", t("modal ok")
            else
                @filesList.addFile attach
                atLeastOne = true

        if atLeastOne
            # show a status bar
            $("#dialog-upload-file").modal("show")

    hideUploadForm: ->
        $('#dialog-upload-file').modal('hide')
        $('#dialog-new-folder').modal('hide')


    ###
        Search
    ###
    onSearchKeyPress: (e) =>
        query = @$('input#search-box').val()

        #if e.keyCode is 13
        if query isnt ""
            @displaySearchResults query
            app.router.navigate "search/#{query}"
        else
            @changeActiveFolder @breadcrumbs.root

    displaySearchResults: (query) ->
        @breadcrumbs.popAll()

        data =
            id: query
            name: "#{t('breadcrumbs search title')} '#{query}'"
            type: "search"

        search = new File data
        @changeActiveFolder search

    onShareClicked: ->
        new ModalShareView model: @model
