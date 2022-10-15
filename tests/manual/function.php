<?php

return function ($event) {
    $name = $event['name'];
    return "Hello $name!";
};
