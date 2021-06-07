	$(document).ready(function(){
		$('a').click(function(){
			//alert("click")
		var selected=$(this);
		$('a').removeClass('active');
		$(selected).addClass('active');
		});

		var $a=$('.a'),
		$b=$('.b'),
		$c=$('.c'),
		$d=$('.d'),
		$e=$('.e'),
		$home=$('.home'),
		$aboutme=$('.aboutme');
		$gallery=$('.gallery');
		$career=$('.career');
		$contactme=$('.contactme');

		$a.click(function(){
			$home.fadeIn();
			$aboutme.fadeOut();
			$gallery.fadeOut();
			$career.fadeOut();
			$contactme.fadeOut();
		});

		$b.click(function(){
			$aboutme.fadeIn();
			$home.fadeOut();
			$gallery.fadeOut();
			$career.fadeOut();
			$contactme.fadeOut();
		});

		$c.click(function(){
			$gallery.fadeIn();
			$home.fadeOut();
			$aboutme.fadeOut();
			$career.fadeOut();
			$contactme.fadeOut();
		});

		$d.click(function(){
			$career.fadeIn();
			$contactme.fadeOut();
			$home.fadeOut();
			$aboutme.fadeOut();
			$gallery.fadeOut(); 
		});

		$e.click(function(){
			$career.fadeOut();
			$contactme.fadeIn();
			$home.fadeOut();
			$aboutme.fadeOut();
			$gallery.fadeOut(); 
		});
	});
