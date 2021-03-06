BaseView = require '../lib/base_view'
Autocomplete = require './autocomplete'

module.exports = class TagsView extends BaseView

    events: ->
        'click .tag': 'tagClicked'
        'click .tag .deleter': 'deleteTag'
        'focus input': 'onFocus'
        'keydown input': 'onKeyDown'
        'keyup input': 'refreshAutocomplete'

    template: -> """
        <input type="text" placeholder="#{t('tag')}">
    """

    initialize: ->
        @listenTo @model, 'change:tags', @refresh

    onFocus: (e) ->
        TagsView.autocomplete.bind this.$el
        TagsView.autocomplete.refresh '', @tags

    onKeyDown: (e) =>

        val = @input.val()

        if val is '' and e.keyCode is 8 #BACKSPACE
            @tags = @tags[0..-2]
            @model.save tags: @tags
            @refresh()
            TagsView.autocomplete.refresh('', @tags)
            TagsView.autocomplete.position()
            e.preventDefault()
            e.stopPropagation()
            return

        # COMMA, SPACE, TAB, ENTER
        if val and e.keyCode in [188, 32, 9, 13]
            @tags.push val unless val in @tags
            @model.save tags: @tags
            @input.val ''
            @refresh()
            TagsView.autocomplete.refresh('', @tags)
            TagsView.autocomplete.position()
            e.preventDefault()
            e.stopPropagation()
            return

        if e.keyCode in [188, 32, 9, 13]
            e.preventDefault()
            e.stopPropagation()
            return

        #UP, DOWN
        if e.keyCode in [40, 38]
            return true

        if val and e.keyCode isnt 8
            @refreshAutocomplete()
            return true

    refreshAutocomplete: (e) =>
        return if e?.keyCode in [40, 38, 8]
        TagsView.autocomplete.refresh @input.val(), @tags

    deleteTag: (e) =>
        tag = e.target.parentNode.dataset.value
        @model.save
            tags: @tags = _.without @tags, tag

    afterRender: ->
        @refresh()
        @tags = @model.get('tags')
        @input = @$('input')

    refresh: =>
        @$('.tag').remove()
        html = ("""
                <li class="tag" data-value="#{tag}">
                    #{tag}
                    <span class="deleter"> &times; </span>
                </li>
            """ for tag in @model.get('tags') or []).join ''
        @$el.prepend html

TagsView.autocomplete = new Autocomplete(id: 'tagsAutocomplete')
TagsView.autocomplete.render()