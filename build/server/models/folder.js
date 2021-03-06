// Generated by CoffeeScript 1.7.1
var CozyInstance, Folder, americano, moment;

americano = require('americano-cozy');

moment = require('moment');

CozyInstance = require('./cozy_instance');

module.exports = Folder = americano.getModel('Folder', {
  path: String,
  name: String,
  docType: String,
  creationDate: String,
  lastModification: String,
  size: Number,
  modificationHistory: Object,
  changeNotification: Boolean,
  clearance: function(x) {
    return x;
  },
  tags: function(x) {
    return x;
  }
});

Folder.all = function(params, callback) {
  return Folder.request("all", params, callback);
};

Folder.byFolder = function(params, callback) {
  return Folder.request("byFolder", params, callback);
};

Folder.byFullPath = function(params, callback) {
  return Folder.request("byFullPath", params, callback);
};

Folder.createNewFolder = function(folder, callback) {
  return Folder.create(folder, function(err, newFolder) {
    if (err) {
      return callback(err);
    } else {
      return newFolder.index(["name"], function(err) {
        if (err) {
          console.log(err);
        }
        return callback(null, newFolder);
      });
    }
  });
};

Folder.allPath = function(callback) {
  return Folder.request("byFullPath", function(err, folders) {
    var folder, paths, _i, _len;
    if (err) {
      return callback(err);
    }
    paths = [];
    for (_i = 0, _len = folders.length; _i < _len; _i++) {
      folder = folders[_i];
      paths.push(folder.getFullPath());
    }
    return callback(null, paths);
  });
};

Folder.prototype.getFullPath = function() {
  return "" + this.path + "/" + this.name;
};

Folder.prototype.getParents = function(callback) {
  var foldersOfPath, parent, parentFoldersPath;
  foldersOfPath = this.getFullPath().split('/');
  parentFoldersPath = [];
  while (foldersOfPath.length > 0) {
    parent = foldersOfPath.join('/');
    if (parent !== "") {
      parentFoldersPath.push(parent);
    }
    foldersOfPath.pop();
  }
  return Folder.byFullPath({
    keys: parentFoldersPath.reverse()
  }, callback);
};

Folder.prototype.getPublicURL = function(cb) {
  return CozyInstance.getURL((function(_this) {
    return function(err, domain) {
      var url;
      if (err) {
        return cb(err);
      }
      url = "" + domain + "public/files/folders/" + _this.id;
      return cb(null, url);
    };
  })(this));
};

Folder.prototype.updateParentModifDate = function(callback) {
  return Folder.byFullPath({
    key: this.path
  }, (function(_this) {
    return function(err, parents) {
      var parent;
      if (err) {
        return callback(err);
      } else if (parents.length > 0) {
        parent = parents[0];
        parent.lastModification = moment().toISOString();
        return parent.save(callback);
      } else {
        return callback();
      }
    };
  })(this));
};

if (process.env.NODE_ENV === 'test') {
  Folder.prototype.index = function(fields, callback) {
    return callback(null);
  };
  Folder.prototype.search = function(query, callback) {
    return callback(null, []);
  };
}
