$(document).ready(function() {
  $('#gems').DataTable();

  $(".rest-delete").restfulizer({
    parse: true,
    method: "DELETE"
  });
} );