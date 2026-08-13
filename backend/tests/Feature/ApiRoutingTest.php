<?php

namespace Tests\Feature;

use Tests\TestCase;

class ApiRoutingTest extends TestCase
{
    public function test_callback_endpoint_rejects_browser_get_requests(): void
    {
        $this->get('/api/payments/callback')
            ->assertMethodNotAllowed();
    }

    public function test_protected_api_route_returns_unauthorized_instead_of_redirecting_to_login(): void
    {
        $this->get('/api/payments/1')
            ->assertUnauthorized();
    }
}
