(function($)
{
  $("form.delete-form").submit(function()
  {
    return confirm("Are you sure you want to delete this gem?");
  });
  var timerName = 'hover:lazy', realHover = function()
  {
  	this.find('button').css('visibility', 'visible');
  }, realNoHover = function()
  {
  	this.find('button').css('visibility', 'hidden');
  }, needHover = function()
  {
  	var self = this, timer = this.data(timerName);
	if (timer !== null)
	{
		clearTimeout(timer);
	}
	this.data(timerName, setTimeout(function()
	{
		realHover.call(self);
	}, 100));
  }, needNoHover = function()
  {
  	var self = this, timer = this.data(timerName);
	if (timer !== null)
	{
		clearTimeout(timer);
	}
	this.data(timerName, setTimeout(function()
	{
		realNoHover.call(self);
	}, 100));
  };
  $('form.delete-form').hover(function()
  {
		needHover.call($(this));
  }, function()
  {
		needNoHover.call($(this));
  });
})(jQuery);

